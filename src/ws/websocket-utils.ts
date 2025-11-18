/**
 * WebSocket utility functions for broadcasting messages
 *
 * Supports both Redis pub/sub (for multi-server deployments) and
 * direct WebSocket broadcasting (for single-server optimization)
 */

import { getRedisPublisher, getRedisSubscriber } from '../config/redis-pubsub.js';
import { WebSocket } from 'ws';
import { logInfo, logError, logWarning } from '../shared/logger.js';
import {
  queueBroadcast,
  drainRetryQueue,
  getConnectionMetadata,
  getRoomResubscribeBatch,
} from './connection-manager.js';

// Configuration: Maximum connections per room
const MAX_CONNECTIONS_PER_ROOM = parseInt(process.env.WS_MAX_CONNECTIONS_PER_ROOM || '1000', 10);

/**
 * Room-based WebSocket client mapping for efficient direct broadcasting
 * Maps roomId -> Set of WebSocket connections
 * Uses Set for iteration support, but ensures cleanup on connection close
 */
const roomClientMap = new Map<string, Set<WebSocket>>();

/**
 * Track room connection counts (for distributed systems via Redis)
 */
let redisSubscriberInitialized = false;

/**
 * Track which rooms each WebSocket connection is subscribed to
 * Maps WebSocket -> Set of roomIds
 */
const wsRoomMap = new WeakMap<WebSocket, Set<string>>();

/**
 * Get connection count for a room (local + distributed via Redis)
 */
async function getRoomConnectionCount(roomId: string): Promise<number> {
  // Get local connection count
  const localCount = roomClientMap.get(roomId)?.size || 0;

  // Try to get distributed count from Redis (if available)
  try {
    const redis = getRedisPublisher();
    if (redis) {
      const redisKey = `room:connections:${roomId}`;
      const distributedCount = await redis.get(redisKey);
      if (distributedCount) {
        return parseInt(distributedCount, 10);
      }
    }
  } catch (error) {
    // Non-critical: fall back to local count
    logWarning(
      'Failed to get distributed connection count',
      error instanceof Error ? error : new Error(String(error))
    );
  }

  return localCount;
}

/**
 * Update room connection count in Redis (for distributed systems)
 */
async function updateRoomConnectionCount(roomId: string, delta: number): Promise<void> {
  try {
    const redis = getRedisPublisher();
    if (redis) {
      const redisKey = `room:connections:${roomId}`;
      const currentCount = await redis.get(redisKey);
      const newCount = Math.max(0, parseInt(currentCount || '0', 10) + delta);
      await redis.setex(redisKey, 3600, newCount.toString()); // 1 hour TTL
    }
  } catch (error) {
    // Non-critical: log but don't fail
    logWarning(
      'Failed to update distributed connection count',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Register a WebSocket connection to a room
 * Used for efficient room-based broadcasting
 * Enforces room connection limits
 */
export async function registerWebSocketToRoom(ws: WebSocket, roomId: string): Promise<boolean> {
  // Check room connection limit
  const currentCount = await getRoomConnectionCount(roomId);
  if (currentCount >= MAX_CONNECTIONS_PER_ROOM) {
    logWarning(
      `Room connection limit exceeded: ${roomId} (${currentCount}/${MAX_CONNECTIONS_PER_ROOM})`
    );
    ws.send(
      JSON.stringify({
        type: 'error',
        msg: 'room_full',
        reason: `Room has reached maximum capacity (${MAX_CONNECTIONS_PER_ROOM} connections)`,
      })
    );
    return false;
  }

  // Add WebSocket to room's client set
  if (!roomClientMap.has(roomId)) {
    roomClientMap.set(roomId, new Set());
  }
  const wasNew = !roomClientMap.get(roomId)!.has(ws);
  roomClientMap.get(roomId)!.add(ws);

  // Track room membership for this WebSocket (using WeakMap for automatic cleanup)
  if (!wsRoomMap.has(ws)) {
    wsRoomMap.set(ws, new Set());
  }
  wsRoomMap.get(ws)!.add(roomId);

  // Update distributed connection count if this is a new connection
  if (wasNew) {
    await updateRoomConnectionCount(roomId, 1);
  }

  logInfo('WebSocket registered to room', { roomId, localCount: roomClientMap.get(roomId)!.size });
  return true;
}

/**
 * Unregister a WebSocket connection from a room
 * Called when connection closes or leaves room
 */
export async function unregisterWebSocketFromRoom(ws: WebSocket, roomId: string): Promise<void> {
  // Remove WebSocket from room's client set
  const clients = roomClientMap.get(roomId);
  let wasRemoved = false;
  if (clients) {
    wasRemoved = clients.delete(ws);
    // Clean up room entry if no clients remain
    if (clients.size === 0) {
      roomClientMap.delete(roomId);
    }
  }

  // Remove room from WebSocket's room set (WeakMap handles cleanup automatically)
  const rooms = wsRoomMap.get(ws);
  if (rooms) {
    rooms.delete(roomId);
  }

  // Update distributed connection count if connection was removed
  if (wasRemoved) {
    await updateRoomConnectionCount(roomId, -1);
  }

  logInfo('WebSocket unregistered from room', { roomId });
}

/**
 * Unregister WebSocket from all rooms
 * Called when connection closes
 */
export async function unregisterWebSocket(ws: WebSocket): Promise<void> {
  const rooms = wsRoomMap.get(ws);
  if (rooms) {
    // Create array copy since we'll be modifying the set
    const roomIds = Array.from(rooms);
    for (const roomId of roomIds) {
      await unregisterWebSocketFromRoom(ws, roomId);
    }
  }
}

/**
 * Broadcast queue for batching messages and implementing backpressure
 */
const broadcastQueue = new Map<string, Array<{ message: any; timestamp: number }>>();
const BATCH_SIZE = 10; // Maximum messages per batch
const BATCH_INTERVAL_MS = 50; // Maximum time to wait before sending batch
const MAX_QUEUE_SIZE = 100; // Maximum queue size before dropping messages (backpressure)
const RETRY_TTL_MS = 60000; // 60 seconds TTL for retry messages
const ROOM_RESUBSCRIBE_BATCH = parseInt(process.env.WS_ROOM_RESUBSCRIBE_BATCH || '10', 10);

/**
 * Track Redis failover state
 */
let redisFailoverInProgress = false;
let lastRedisFailoverTime = 0;

/**
 * Process broadcast queue for a room (called periodically)
 * Enhanced with retry logic and failover handling
 */
function processBroadcastQueue(roomId: string): void {
  const queue = broadcastQueue.get(roomId);
  if (!queue || queue.length === 0) {
    return;
  }

  // Filter out expired messages (TTL check)
  const now = Date.now();
  const validMessages = queue.filter((item) => now - item.timestamp < RETRY_TTL_MS);
  const expiredCount = queue.length - validMessages.length;

  if (expiredCount > 0) {
    logWarning('Dropping expired broadcast messages', { roomId, expiredCount });
  }

  if (validMessages.length === 0) {
    broadcastQueue.delete(roomId);
    return;
  }

  // Update queue with valid messages only
  broadcastQueue.set(roomId, validMessages);

  // Take up to BATCH_SIZE messages from queue
  const batch = validMessages.splice(0, BATCH_SIZE);
  const payload = JSON.stringify(batch.map((b) => b.message));

  // Broadcast batch via direct WebSocket connections
  const clients = roomClientMap.get(roomId);
  if (clients && clients.size > 0) {
    let sentCount = 0;
    let failedConnections: WebSocket[] = [];

    for (const client of clients) {
      if (client.readyState === WebSocket.OPEN) {
        try {
          client.send(payload);
          sentCount++;
        } catch (error: unknown) {
          const errorMessage = error instanceof Error ? error.message : 'Unknown error';
          logError(
            'Failed to send WebSocket batch',
            error instanceof Error ? error : new Error(errorMessage),
            { roomId }
          );
          failedConnections.push(client);

          // Queue failed broadcast for retry
          batch.forEach(({ message }) => {
            queueBroadcast(client, roomId, message);
          });
        }
      } else {
        failedConnections.push(client);
      }
    }

    // Clean up failed connections
    for (const client of failedConnections) {
      unregisterWebSocketFromRoom(client, roomId).catch(() => {
        // Ignore cleanup errors
      });
    }

    if (sentCount > 0) {
      logInfo('Broadcasted batch via direct WebSocket', {
        roomId,
        batchSize: batch.length,
        sentCount,
      });

      // If Redis failover is in progress, still publish to Redis for consistency
      if (redisFailoverInProgress) {
        publishBatchToRedis(roomId, batch);
      }
      return;
    }
  }

  // Fallback to Redis pub/sub for the batch
  publishBatchToRedis(roomId, batch);
}

/**
 * Publish batch to Redis with failover handling
 */
function publishBatchToRedis(
  roomId: string,
  batch: Array<{ message: any; timestamp: number }>
): void {
  try {
    const publisher = getRedisPublisher();
    if (!publisher) {
      logWarning('Redis publisher not available, dropping batch', {
        roomId,
        batchSize: batch.length,
      });
      return;
    }

    batch.forEach(({ message }) => {
      publisher.publish(`room:${roomId}`, JSON.stringify(message));
    });
    logInfo('Broadcasted batch via Redis pub/sub', { roomId, batchSize: batch.length });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError(
      'Failed to broadcast batch via Redis',
      error instanceof Error ? error : new Error(errorMessage),
      { roomId }
    );

    // Mark Redis failover in progress
    redisFailoverInProgress = true;
    lastRedisFailoverTime = Date.now();
  }
}

/**
 * Broadcast a message to all clients in a room
 * Uses batching and backpressure to optimize performance
 * Enhanced with retry queue and failover handling
 *
 * @param roomId - Room ID to broadcast to
 * @param message - Message to broadcast
 * @param useDirectBroadcast - If true, use direct WebSocket broadcast (default: true)
 */
export function broadcastToRoom(
  roomId: string,
  message: any,
  useDirectBroadcast: boolean = true
): void {
  // Check if Redis failover is in progress
  if (redisFailoverInProgress) {
    const timeSinceFailover = Date.now() - lastRedisFailoverTime;
    // Reset failover flag after 5 seconds
    if (timeSinceFailover > 5000) {
      redisFailoverInProgress = false;
      logInfo('Redis failover recovery complete', {});
    }
  }

  // Add to broadcast queue for batching
  if (!broadcastQueue.has(roomId)) {
    broadcastQueue.set(roomId, []);
    // Schedule queue processing
    setTimeout(() => processBroadcastQueue(roomId), BATCH_INTERVAL_MS);
  }

  const queue = broadcastQueue.get(roomId)!;

  // Backpressure: drop oldest messages if queue is too large
  if (queue.length >= MAX_QUEUE_SIZE) {
    const dropped = queue.shift(); // Drop oldest
    logWarning('Broadcast queue full, dropping oldest message', {
      roomId,
      queueSize: queue.length,
      droppedTimestamp: dropped?.timestamp,
    });
  }

  // Add message to queue
  queue.push({ message, timestamp: Date.now() });

  // If queue reaches batch size, process immediately
  if (queue.length >= BATCH_SIZE) {
    processBroadcastQueue(roomId);
  }

  // Also try direct broadcast for low-latency (non-batched)
  if (useDirectBroadcast) {
    const payload = JSON.stringify(message);
    const clients = roomClientMap.get(roomId);
    if (clients && clients.size > 0) {
      let sentCount = 0;
      for (const client of clients) {
        if (client.readyState === WebSocket.OPEN) {
          try {
            client.send(payload);
            sentCount++;
          } catch (error: unknown) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown error';
            logError(
              'Failed to send WebSocket message',
              error instanceof Error ? error : new Error(errorMessage)
            );
            unregisterWebSocketFromRoom(client, roomId).catch(() => {
              // Ignore cleanup errors
            });
          }
        } else {
          unregisterWebSocketFromRoom(client, roomId).catch(() => {
            // Ignore cleanup errors
          });
        }
      }

      if (sentCount > 0) {
        logInfo('Broadcasted via direct WebSocket', { roomId, sentCount });
        return; // Successfully sent via direct broadcast
      }
    }
  }

  // Always publish to Redis pub/sub for cross-process broadcasting
  // This ensures messages reach all server instances in a clustered deployment
  try {
    const publisher = getRedisPublisher();
    if (publisher) {
      publisher.publish(`room:${roomId}`, JSON.stringify(message));
      logInfo('Broadcasted via Redis pub/sub', { roomId });
    }
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError(
      'Failed to broadcast via Redis',
      error instanceof Error ? error : new Error(errorMessage)
    );
  }
}

/**
 * Initialize Redis subscriber for cross-process message broadcasting
 * Subscribes to room channels and broadcasts to local WebSocket connections
 * Handles Redis failover and reconnection automatically
 * Enhanced with failover detection and room resubscription
 */
export function initializeRedisSubscriber(): void {
  if (redisSubscriberInitialized) {
    return; // Already initialized
  }

  try {
    const subscriber = getRedisSubscriber();
    if (!subscriber) {
      logWarning('Redis subscriber not available, skipping cross-process broadcasting setup');
      return;
    }

    // Setup reconnection handler for failover scenarios
    subscriber.on('reconnecting', (delay: number) => {
      logInfo('Redis subscriber reconnecting (failover detected)', { delay });
      redisFailoverInProgress = true;
      lastRedisFailoverTime = Date.now();
    });

    subscriber.on('ready', () => {
      logInfo('Redis subscriber ready after failover', {});
      redisFailoverInProgress = false;

      // Resubscribe after reconnection
      subscribeToRoomChannels(subscriber);

      // Trigger room resubscription for all active connections
      resubscribeAllRooms();
    });

    subscriber.on('error', (err: Error) => {
      logError('Redis subscriber error', err);
      redisFailoverInProgress = true;
      lastRedisFailoverTime = Date.now();
    });

    // Initial subscription
    subscribeToRoomChannels(subscriber);

    // Handle incoming messages from other server instances
    subscriber.on('pmessage', (pattern: string, channel: string, message: string) => {
      try {
        const roomId = channel.replace('room:', '');
        const messageData = JSON.parse(message);

        // Broadcast to local WebSocket connections in this room
        const clients = roomClientMap.get(roomId);
        if (clients && clients.size > 0) {
          let sentCount = 0;
          for (const client of clients) {
            if (client.readyState === WebSocket.OPEN) {
              try {
                client.send(JSON.stringify(messageData));
                sentCount++;
              } catch (error: unknown) {
                logError(
                  'Failed to send cross-process message',
                  error instanceof Error ? error : new Error(String(error))
                );
                unregisterWebSocketFromRoom(client, roomId).catch(() => {
                  // Ignore cleanup errors
                });
              }
            }
          }

          if (sentCount > 0) {
            logInfo('Broadcasted cross-process message to local clients', { roomId, sentCount });
          }
        }
      } catch (error: unknown) {
        logError(
          'Failed to process cross-process message',
          error instanceof Error ? error : new Error(String(error))
        );
      }
    });

    redisSubscriberInitialized = true;
  } catch (error: unknown) {
    logError(
      'Failed to initialize Redis subscriber',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Subscribe to Redis room channels
 * Handles subscription errors and retries with exponential backoff
 */
function subscribeToRoomChannels(subscriber: any, retryAttempt: number = 0): void {
  try {
    // Subscribe to all room channels (pattern: room:*)
    subscriber.psubscribe('room:*', (err: Error | null) => {
      if (err) {
        logError('Failed to subscribe to Redis room channels', err, { retryAttempt });

        // Exponential retry: 5s, 10s, 20s, max 30s
        const retryDelay = Math.min(30000, 5000 * Math.pow(2, retryAttempt));
        setTimeout(() => subscribeToRoomChannels(subscriber, retryAttempt + 1), retryDelay);
        return;
      }

      logInfo('Subscribed to Redis room channels for cross-process broadcasting', { retryAttempt });
      redisFailoverInProgress = false;
    });
  } catch (error: unknown) {
    logError(
      'Error subscribing to Redis channels',
      error instanceof Error ? error : new Error(String(error)),
      { retryAttempt }
    );

    // Retry on exception
    const retryDelay = Math.min(30000, 5000 * Math.pow(2, retryAttempt));
    setTimeout(() => subscribeToRoomChannels(subscriber, retryAttempt + 1), retryDelay);
  }
}

/**
 * Resubscribe all active connections to their rooms
 * Called after Redis failover recovery
 */
function resubscribeAllRooms(): void {
  logInfo('Resubscribing all connections to rooms after Redis failover', {});

  // Iterate through all rooms and resubscribe connections
  for (const [roomId, clients] of roomClientMap.entries()) {
    for (const client of clients) {
      const metadata = getConnectionMetadata(client);
      if (metadata && metadata.subscribedRooms.has(roomId)) {
        // Connection is already in room map, just ensure subscription is tracked
        // The actual resubscription happens in gateway.ts resubscribeToRooms()
        logInfo('Connection already in room after failover', { roomId, userId: metadata.userId });
      }
    }
  }
}

/**
 * Batch resubscribe connections to rooms
 * Used for efficient room restoration after reconnection
 *
 * @param ws - WebSocket connection
 * @returns Promise resolving to number of rooms resubscribed
 */
export async function batchResubscribeRooms(ws: WebSocket): Promise<number> {
  const metadata = getConnectionMetadata(ws);
  if (!metadata) {
    return 0;
  }

  const rooms = getRoomResubscribeBatch(ws, ROOM_RESUBSCRIBE_BATCH);
  if (rooms.length === 0) {
    return 0;
  }

  let successCount = 0;

  // Process in batches
  for (let i = 0; i < rooms.length; i += ROOM_RESUBSCRIBE_BATCH) {
    const batch = rooms.slice(i, i + ROOM_RESUBSCRIBE_BATCH);

    for (const roomId of batch) {
      try {
        const success = await registerWebSocketToRoom(ws, roomId);
        if (success) {
          successCount++;
          logInfo('Room resubscribed in batch', { userId: metadata.userId, roomId });
        }
      } catch (err) {
        logError(
          'Error resubscribing room in batch',
          err instanceof Error ? err : new Error(String(err)),
          {
            userId: metadata.userId,
            roomId,
          }
        );
      }
    }
  }

  return successCount;
}

/**
 * Process retry queue for a connection
 * Drains queued broadcasts and attempts to send them
 *
 * @param ws - WebSocket connection
 */
export function processRetryQueue(ws: WebSocket): void {
  const retryEnvelopes = drainRetryQueue(ws);
  if (retryEnvelopes.length === 0) {
    return;
  }

  logInfo('Processing retry queue', { queueSize: retryEnvelopes.length });

  // Group by room for efficient broadcasting
  const roomGroups = new Map<string, any[]>();
  for (const envelope of retryEnvelopes) {
    if (!roomGroups.has(envelope.roomId)) {
      roomGroups.set(envelope.roomId, []);
    }
    roomGroups.get(envelope.roomId)!.push(envelope.message);
  }

  // Broadcast each room's messages
  for (const [roomId, messages] of roomGroups.entries()) {
    for (const message of messages) {
      broadcastToRoom(roomId, message, true);
    }
  }

  logInfo('Retry queue processed', { processedCount: retryEnvelopes.length });
}
