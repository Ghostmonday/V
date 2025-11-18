/**
 * WebSocket Connection Manager
 *
 * Manages connection state, exponential backoff, room subscriptions,
 * and broadcast retry queues for WebSocket reconnection logic.
 */

import { WebSocket } from 'ws';
import { logInfo, logError, logWarning } from '../shared/logger.js';

/**
 * Connection state machine states
 */
export enum ConnectionState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  AUTHENTICATED = 'authenticated',
  SUBSCRIBED = 'subscribed',
}

/**
 * Connection metadata for tracking per-connection state
 */
export interface ConnectionMetadata {
  ws: WebSocket;
  userId: string;
  state: ConnectionState;
  reconnectAttempts: number;
  lastPing: number;
  lastPong: number;
  connectionStartTime: number;
  subscribedRooms: Set<string>;
  retryQueue: Array<RetryEnvelope>;
  pingLatencies: number[];
}

/**
 * Retry envelope for queued broadcasts
 */
export interface RetryEnvelope {
  roomId: string;
  message: any;
  timestamp: number;
  attempts: number;
}

/**
 * Configuration from environment variables
 */
const EXPONENTIAL_BASE_MS = parseInt(process.env.WS_EXPONENTIAL_BASE_MS || '1000', 10);
const EXPONENTIAL_MAX_MS = parseInt(process.env.WS_EXPONENTIAL_MAX_MS || '30000', 10);
const RETRY_ENVELOPE_SIZE = parseInt(process.env.WS_RETRY_ENVELOPE_SIZE || '50', 10);
const RETRY_TTL_MS = 60000; // 60 seconds TTL for retry messages
const ROOM_RESUBSCRIBE_BATCH = parseInt(process.env.WS_ROOM_RESUBSCRIBE_BATCH || '10', 10);

/**
 * Connection registry: Maps WebSocket to connection metadata
 * Uses WeakMap to prevent memory leaks when connections are garbage collected
 */
const connectionRegistry = new WeakMap<WebSocket, ConnectionMetadata>();

/**
 * User to connections mapping (for tracking multiple connections per user)
 */
const userConnectionsMap = new Map<string, Set<WebSocket>>();

/**
 * Register a new WebSocket connection with metadata
 *
 * @param ws - WebSocket connection
 * @param userId - User ID from authentication
 * @returns ConnectionMetadata for the registered connection
 */
export function registerConnection(ws: WebSocket, userId: string): ConnectionMetadata {
  // Check if connection already registered
  const existing = connectionRegistry.get(ws);
  if (existing) {
    logWarning('Connection already registered', { userId, existingState: existing.state });
    return existing;
  }

  const metadata: ConnectionMetadata = {
    ws,
    userId,
    state: ConnectionState.CONNECTING,
    reconnectAttempts: 0,
    lastPing: Date.now(),
    lastPong: Date.now(),
    connectionStartTime: Date.now(),
    subscribedRooms: new Set(),
    retryQueue: [],
    pingLatencies: [],
  };

  connectionRegistry.set(ws, metadata);

  // Track user connections
  if (!userConnectionsMap.has(userId)) {
    userConnectionsMap.set(userId, new Set());
  }
  userConnectionsMap.get(userId)!.add(ws);

  logInfo('Connection registered', { userId, state: metadata.state });
  return metadata;
}

/**
 * Update connection state with validation
 *
 * @param ws - WebSocket connection
 * @param newState - New state to transition to
 * @returns true if transition is valid, false otherwise
 */
export function updateConnectionState(ws: WebSocket, newState: ConnectionState): boolean {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    logError('Cannot update state: connection not registered', new Error('Connection not found'));
    return false;
  }

  const oldState = metadata.state;

  // Validate state transitions
  const validTransitions: Record<ConnectionState, ConnectionState[]> = {
    [ConnectionState.DISCONNECTED]: [ConnectionState.CONNECTING],
    [ConnectionState.CONNECTING]: [ConnectionState.CONNECTED, ConnectionState.DISCONNECTED],
    [ConnectionState.CONNECTED]: [ConnectionState.AUTHENTICATED, ConnectionState.DISCONNECTED],
    [ConnectionState.AUTHENTICATED]: [ConnectionState.SUBSCRIBED, ConnectionState.DISCONNECTED],
    [ConnectionState.SUBSCRIBED]: [ConnectionState.DISCONNECTED],
  };

  const allowedStates = validTransitions[oldState] || [];
  if (!allowedStates.includes(newState)) {
    logError(
      'Invalid state transition',
      new Error(`Cannot transition from ${oldState} to ${newState}`)
    );
    return false;
  }

  metadata.state = newState;
  logInfo('Connection state updated', { userId: metadata.userId, oldState, newState });
  return true;
}

/**
 * Add room subscription to connection metadata
 *
 * @param ws - WebSocket connection
 * @param roomId - Room ID to subscribe to
 * @returns true if subscription added, false if already subscribed
 */
export function addRoomSubscription(ws: WebSocket, roomId: string): boolean {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    logError(
      'Cannot add subscription: connection not registered',
      new Error('Connection not found')
    );
    return false;
  }

  if (metadata.subscribedRooms.has(roomId)) {
    logWarning('Room already subscribed', { userId: metadata.userId, roomId });
    return false;
  }

  metadata.subscribedRooms.add(roomId);
  logInfo('Room subscription added', {
    userId: metadata.userId,
    roomId,
    totalRooms: metadata.subscribedRooms.size,
  });
  return true;
}

/**
 * Remove room subscription from connection metadata
 *
 * @param ws - WebSocket connection
 * @param roomId - Room ID to unsubscribe from
 */
export function removeRoomSubscription(ws: WebSocket, roomId: string): void {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    return; // Already cleaned up
  }

  metadata.subscribedRooms.delete(roomId);
  logInfo('Room subscription removed', { userId: metadata.userId, roomId });
}

/**
 * Get all subscribed rooms for a connection
 *
 * @param ws - WebSocket connection
 * @returns Array of room IDs, or empty array if connection not found
 */
export function getSubscribedRooms(ws: WebSocket): string[] {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    return [];
  }
  return Array.from(metadata.subscribedRooms);
}

/**
 * Calculate exponential backoff delay with jitter
 *
 * @param attemptCount - Number of reconnection attempts
 * @returns Delay in milliseconds (bounded by EXPONENTIAL_MAX_MS)
 */
export function calculateBackoffDelay(attemptCount: number): number {
  // Calculate base exponential delay
  const baseDelay = EXPONENTIAL_BASE_MS * Math.pow(2, attemptCount);

  // Add jitter: ±10% randomization to prevent thundering herd
  const jitterRange = baseDelay * 0.1;
  const jitter = (Math.random() * 2 - 1) * jitterRange; // -10% to +10%

  // Calculate final delay with jitter
  const delay = baseDelay + jitter;

  // Bound by maximum delay
  const boundedDelay = Math.min(EXPONENTIAL_MAX_MS, Math.max(0, delay));

  // Validation: ensure delay never exceeds max
  if (boundedDelay > EXPONENTIAL_MAX_MS) {
    logError(
      'Backoff delay exceeded maximum',
      new Error(`Delay: ${boundedDelay}ms > Max: ${EXPONENTIAL_MAX_MS}ms`)
    );
    return EXPONENTIAL_MAX_MS;
  }

  return Math.round(boundedDelay);
}

/**
 * Queue a broadcast message for retry
 *
 * @param ws - WebSocket connection
 * @param roomId - Room ID to broadcast to
 * @param message - Message to broadcast
 * @returns true if queued, false if queue full
 */
export function queueBroadcast(ws: WebSocket, roomId: string, message: any): boolean {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    logError(
      'Cannot queue broadcast: connection not registered',
      new Error('Connection not found')
    );
    return false;
  }

  // Check queue size limit
  if (metadata.retryQueue.length >= RETRY_ENVELOPE_SIZE) {
    // Backpressure: drop oldest message
    const dropped = metadata.retryQueue.shift();
    logWarning('Retry queue full, dropping oldest message', {
      userId: metadata.userId,
      droppedRoomId: dropped?.roomId,
      queueSize: metadata.retryQueue.length,
    });
  }

  const envelope: RetryEnvelope = {
    roomId,
    message,
    timestamp: Date.now(),
    attempts: 0,
  };

  metadata.retryQueue.push(envelope);
  logInfo('Broadcast queued for retry', {
    userId: metadata.userId,
    roomId,
    queueSize: metadata.retryQueue.length,
  });
  return true;
}

/**
 * Drain retry queue for a connection (process all queued broadcasts)
 * Removes expired messages (TTL exceeded)
 *
 * @param ws - WebSocket connection
 * @returns Array of valid retry envelopes to process
 */
export function drainRetryQueue(ws: WebSocket): RetryEnvelope[] {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    return [];
  }

  const now = Date.now();
  const validEnvelopes: RetryEnvelope[] = [];
  const expiredCount = metadata.retryQueue.length;

  // Filter out expired messages (TTL check)
  for (const envelope of metadata.retryQueue) {
    const age = now - envelope.timestamp;
    if (age < RETRY_TTL_MS) {
      validEnvelopes.push(envelope);
    } else {
      logWarning('Retry envelope expired, dropping', {
        userId: metadata.userId,
        roomId: envelope.roomId,
        ageMs: age,
      });
    }
  }

  // Clear queue and keep only valid envelopes
  metadata.retryQueue = validEnvelopes;

  if (expiredCount > validEnvelopes.length) {
    logInfo('Drained retry queue', {
      userId: metadata.userId,
      valid: validEnvelopes.length,
      expired: expiredCount - validEnvelopes.length,
    });
  }

  return validEnvelopes;
}

/**
 * Get connection metadata
 *
 * @param ws - WebSocket connection
 * @returns ConnectionMetadata or undefined if not found
 */
export function getConnectionMetadata(ws: WebSocket): ConnectionMetadata | undefined {
  return connectionRegistry.get(ws);
}

/**
 * Update ping/pong timestamps
 *
 * @param ws - WebSocket connection
 * @param isPing - true for ping, false for pong
 */
export function updatePingPong(ws: WebSocket, isPing: boolean): void {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    return;
  }

  const now = Date.now();
  if (isPing) {
    metadata.lastPing = now;
  } else {
    metadata.lastPong = now;

    // Calculate latency if we have a ping time
    if (metadata.lastPing > 0) {
      const latency = now - metadata.lastPing;
      metadata.pingLatencies.push(latency);

      // Keep only last 10 latencies
      if (metadata.pingLatencies.length > 10) {
        metadata.pingLatencies.shift();
      }
    }
  }
}

/**
 * Increment reconnection attempts
 *
 * @param ws - WebSocket connection
 * @returns New attempt count
 */
export function incrementReconnectAttempts(ws: WebSocket): number {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    return 0;
  }

  metadata.reconnectAttempts++;
  logInfo('Reconnection attempt incremented', {
    userId: metadata.userId,
    attempts: metadata.reconnectAttempts,
  });
  return metadata.reconnectAttempts;
}

/**
 * Reset reconnection attempts (on successful connection)
 *
 * @param ws - WebSocket connection
 */
export function resetReconnectAttempts(ws: WebSocket): void {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    return;
  }

  metadata.reconnectAttempts = 0;
  logInfo('Reconnection attempts reset', { userId: metadata.userId });
}

/**
 * Clean up connection metadata (called on disconnect)
 *
 * @param ws - WebSocket connection
 */
export function unregisterConnection(ws: WebSocket): void {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    return; // Already cleaned up
  }

  // Remove from user connections map
  const userConnections = userConnectionsMap.get(metadata.userId);
  if (userConnections) {
    userConnections.delete(ws);
    if (userConnections.size === 0) {
      userConnectionsMap.delete(metadata.userId);
    }
  }

  // Clear retry queue
  metadata.retryQueue = [];
  metadata.subscribedRooms.clear();

  // WeakMap will automatically clean up when WebSocket is garbage collected
  logInfo('Connection unregistered', { userId: metadata.userId });
}

/**
 * Get batch of rooms for re-subscription
 *
 * @param ws - WebSocket connection
 * @param batchSize - Maximum number of rooms per batch
 * @returns Array of room IDs (up to batchSize)
 */
export function getRoomResubscribeBatch(
  ws: WebSocket,
  batchSize: number = ROOM_RESUBSCRIBE_BATCH
): string[] {
  const metadata = connectionRegistry.get(ws);
  if (!metadata) {
    return [];
  }

  const rooms = Array.from(metadata.subscribedRooms);
  return rooms.slice(0, batchSize);
}
