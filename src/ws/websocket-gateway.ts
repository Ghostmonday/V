/**
 * WebSocket gateway using protobuf envelope
 * - uses specs/proto/ws_envelope.proto for decoding
 * - delegates to handlers based on envelope.type
 */

import { WebSocketServer, WebSocket } from 'ws';
import protobuf from 'protobufjs';
import path from 'path';
import { handlePresence } from './handlers/websocket-presence-handler.js';
import { handleMessaging } from './handlers/websocket-messaging-handler.js';
import { handleReadReceipt } from './handlers/websocket-read-receipts-handler.js';
import { handleDeliveryAckMessage } from './handlers/websocket-delivery-ack-handler.js';
import { logInfo, logError, logWarning } from '../shared/logger-shared.js';
import {
  registerWebSocketToRoom,
  unregisterWebSocket,
  initializeRedisSubscriber,
} from './websocket-utils.js';
import { verifyToken } from '../services/user-authentication-service.js';
import {
  registerConnection,
  updateConnectionState,
  removeConnection,
  getConnection,
  getConnectionsByUserId,
  getConnectionsCount,
  getConnectionMetadata,
  updatePingPong,
  incrementReconnectAttempts,
  resetReconnectAttempts,
  unregisterConnection,
  getRoomResubscribeBatch,
  addRoomSubscription,
  getSubscribedRooms,
  calculateBackoffDelay,
  ConnectionState,
  drainRetryQueue,
} from './websocket-connection-manager.js';
import { getRedisSubscriber } from '../config/redis-pubsub-config.js';

// Protobuf schema root (loaded from .proto file)
// Null until schema is loaded
let root: protobuf.Root | null = null;
// Promise to track loading state and prevent race conditions
let loadPromise: Promise<protobuf.Root> | null = null;

/**
 * Load protobuf schema definition
 *
 * Protobuf provides efficient binary serialization for WebSocket messages.
 * Schema defines message structure (type, payload, etc.)
 *
 * Uses a promise to prevent race conditions when multiple connections
 * try to load the schema simultaneously.
 */
async function loadProto(): Promise<protobuf.Root> {
  // If already loaded, return immediately
  if (root) {
    return root;
  }

  // If loading is in progress, wait for existing promise
  if (loadPromise) {
    return loadPromise;
  }

  // Start loading and store promise to prevent concurrent loads
  loadPromise = (async () => {
    try {
      // Load .proto file from specs directory
      // process.cwd() = project root (works in both dev and production builds)
      // Path is relative to project root: specs/proto/ws_envelope.proto
      root = (await protobuf.load(path.join(process.cwd(), 'specs/proto/ws_envelope.proto'))) as any;
      return root!;
    } catch (err) {
      // Reset promise on error so we can retry
      loadPromise = null;
      throw err;
    }
  })();

  return loadPromise;
}

// Load schema on module init (non-blocking - errors are warnings)
loadProto().catch((err) => {
  // Log error but don't crash - proto loading failures will be handled per-connection
  console.warn('[WebSocket] Failed to preload protobuf schema:', err);
});

/**
 * Setup WebSocket gateway with protobuf message handling
 *
 * Handles incoming WebSocket connections and routes messages based on type.
 * Uses protobuf for efficient binary message encoding/decoding.
 *
 * WebSocket authentication is performed on connection via query parameters.
 */
export function setupWebSocketGateway(wss: WebSocketServer) {
  // Initialize Redis subscriber for cross-process broadcasting
  initializeRedisSubscriber();

  // Setup Redis failover listeners
  setupRedisFailoverListeners();

  // Listen for new WebSocket connections
  wss.on(
    'connection',
    async (
      ws: WebSocket & { alive?: number; pingTimeout?: NodeJS.Timeout; userId?: string },
      req: any
    ) => {
      // Extract authentication from query parameters
      const url = new URL(req.url || '', `http://${req.headers.host}`);
      const userId = url.searchParams.get('userId');
      const token = url.searchParams.get('token');

      // Authenticate WebSocket connection
      if (!userId || !token) {
        ws.send(JSON.stringify({ type: 'error', msg: 'authentication required' }));
        ws.close(1008, 'Authentication required');
        return;
      }

      // Verify token with auth service
      try {
        const decoded = await verifyToken(token);
        // Verify that the token belongs to the user claiming it
        if (decoded.userId !== userId) {
          ws.send(JSON.stringify({ type: 'error', msg: 'invalid token for user' }));
          ws.close(1008, 'Invalid token for user');
          return;
        }
      } catch (err) {
        ws.send(JSON.stringify({ type: 'error', msg: 'invalid token' }));
        ws.close(1008, 'Invalid token');
        return;
      }

      // Store userId on websocket for later use
      ws.userId = userId;

      // Register connection with connection manager (state: CONNECTING)
      const connectionMetadata = registerConnection(ws, userId);
      updateConnectionState(ws, ConnectionState.CONNECTING);
      logInfo('WebSocket connection initiated', { userId, state: ConnectionState.CONNECTING });

      // Ensure protobuf schema is loaded before accepting messages
      try {
        await loadProto();
      } catch (err) {
        ws.send(JSON.stringify({ type: 'error', msg: 'server initialization failed' }));
        ws.close(1011, 'Server initialization failed');
        updateConnectionState(ws, ConnectionState.DISCONNECTED);
        unregisterConnection(ws);
        return;
      }

      // VALIDATION CHECKPOINT: Validate connection established
      if (ws.readyState !== WebSocket.OPEN) {
        ws.close(1006, 'Connection not open');
        updateConnectionState(ws, ConnectionState.DISCONNECTED);
        unregisterConnection(ws);
        return;
      }

      // Transition to CONNECTED state
      updateConnectionState(ws, ConnectionState.CONNECTED);
      logInfo('WebSocket connection established', { userId, state: ConnectionState.CONNECTED });

      // Mark connection as alive
      ws.alive = Date.now();

      // Configuration: Idle timeout (5 minutes = 300000ms)
      const IDLE_TIMEOUT_MS = parseInt(process.env.WS_IDLE_TIMEOUT_MS || '300000', 10);
      const BASE_PING_INTERVAL_MS = parseInt(process.env.WS_PING_INTERVAL_MS || '30000', 10);
      const ADAPTIVE_PING_ENABLED = process.env.WS_PING_ADAPTIVE !== 'false';

      // VALIDATION CHECKPOINT: Validate timeout configuration
      if (IDLE_TIMEOUT_MS < 60000 || IDLE_TIMEOUT_MS > 600000) {
        logError(
          'Invalid WS_IDLE_TIMEOUT_MS configuration',
          new Error(`Value ${IDLE_TIMEOUT_MS} out of range`)
        );
      }

      // Get connection metadata from connection manager
      const metadata = getConnectionMetadata(ws);
      if (!metadata) {
        logError('Connection metadata not found', new Error('Connection not registered'));
        ws.close(1011, 'Internal server error');
        return;
      }

      // Use metadata for tracking (already initialized in registerConnection)
      const connectionStartTime = metadata.connectionStartTime;

      // Calculate adaptive ping interval based on connection quality
      const getAdaptivePingInterval = (): number => {
        if (!ADAPTIVE_PING_ENABLED) {
          return BASE_PING_INTERVAL_MS;
        }

        const metadata = getConnectionMetadata(ws);
        if (!metadata || metadata.pingLatencies.length === 0) {
          return BASE_PING_INTERVAL_MS;
        }

        // Calculate average latency
        const avgLatency =
          metadata.pingLatencies.reduce((a, b) => a + b, 0) / metadata.pingLatencies.length;

        // Adaptive logic: increase ping interval if latency is high (poor connection)
        // Good connection (< 100ms): use base interval
        // Poor connection (> 500ms): use 2x interval
        if (avgLatency < 100) {
          return BASE_PING_INTERVAL_MS;
        } else if (avgLatency > 500) {
          return BASE_PING_INTERVAL_MS * 2;
        } else {
          // Linear interpolation between base and 2x
          const factor = 1 + (avgLatency - 100) / 400; // 1.0 to 2.0
          return Math.round(BASE_PING_INTERVAL_MS * factor);
        }
      };

      // Ping-pong health check with adaptive intervals and jitter
      // Prevents queue storms under load by randomizing ping intervals
      const schedulePing = () => {
        // Clear any existing timeout
        if (ws.pingTimeout) {
          clearTimeout(ws.pingTimeout);
        }

        // Get adaptive ping interval
        const adaptiveInterval = getAdaptivePingInterval();

        // Calculate jitter: base interval + random -1s to +1s
        const jitter = Math.random() * 2000 - 1000; // -1000ms to +1000ms
        const interval = adaptiveInterval + jitter;

        // Debounce: wrap ping in setTimeout with 5ms debounce
        ws.pingTimeout = setTimeout(() => {
          // VALIDATION CHECKPOINT: Validate connection still open
          if (ws.readyState !== WebSocket.OPEN) {
            return;
          }

          const metadata = getConnectionMetadata(ws);
          if (!metadata) {
            return; // Connection already cleaned up
          }

          // VALIDATION CHECKPOINT: Validate idle timeout
          const timeSinceLastActivity = ws.alive ? Date.now() - ws.alive : Infinity;
          if (timeSinceLastActivity > IDLE_TIMEOUT_MS) {
            // Connection idle too long - close it
            logError(
              'WebSocket connection idle timeout',
              new Error(`${timeSinceLastActivity}ms > ${IDLE_TIMEOUT_MS}ms`),
              { userId }
            );
            ws.close(1001, 'Idle timeout');
            updateConnectionState(ws, ConnectionState.DISCONNECTED);
            return;
          }

          // Check if last pong was more than 1 minute ago
          const timeSinceLastPong = Date.now() - metadata.lastPong;
          if (timeSinceLastPong > 60000) {
            // Connection appears dead - close it
            logError(
              'WebSocket connection appears dead (no pong response)',
              new Error('No pong for >60s'),
              { userId, timeSinceLastPong }
            );
            ws.close(1001, 'Connection timeout');
            updateConnectionState(ws, ConnectionState.DISCONNECTED);
            return;
          }

          // Update ping timestamp in connection manager
          updatePingPong(ws, true);

          // Send ping with 5ms debounce
          setTimeout(() => {
            if (ws.readyState === WebSocket.OPEN) {
              ws.ping();
            }
          }, 5);

          // Schedule next ping
          schedulePing();
        }, interval);
      };

      // Start ping cycle
      schedulePing();

      // Calculate connection quality score (0-1)
      const getConnectionQuality = (): number => {
        const metadata = getConnectionMetadata(ws);
        if (!metadata || metadata.pingLatencies.length === 0) return 1.0;
        const avgLatency =
          metadata.pingLatencies.reduce((a, b) => a + b, 0) / metadata.pingLatencies.length;
        // Quality decreases as latency increases (100ms = 1.0, 1000ms = 0.0)
        return Math.max(0, Math.min(1, 1 - avgLatency / 1000));
      };

      // Log connection quality metrics to telemetry
      const logConnectionQualityMetrics = async () => {
        try {
          const metadata = getConnectionMetadata(ws);
          if (!metadata) return;

          const quality = getConnectionQuality();
          const avgLatency =
            metadata.pingLatencies.length > 0
              ? metadata.pingLatencies.reduce((a, b) => a + b, 0) / metadata.pingLatencies.length
              : 0;
          const connectionDuration = Date.now() - connectionStartTime;

          // Import telemetry service dynamically
          const { logTelemetryEvent } = await import('../telemetry/telemetry-exports.js');
          await logTelemetryEvent('websocket_connection_quality', {
            userId: ws.userId,
            metadata: {
              quality_score: quality,
              avg_latency_ms: avgLatency,
              connection_duration_ms: connectionDuration,
              reconnect_attempts: metadata.reconnectAttempts,
              ping_count: metadata.pingLatencies.length,
              state: metadata.state,
              subscribed_rooms: metadata.subscribedRooms.size,
            },
          });
        } catch (error) {
          // Non-critical: log but don't block
          logError(
            'Failed to log connection quality metrics',
            error instanceof Error ? error : new Error(String(error))
          );
        }
      };

      // Automatic room re-subscription after reconnect
      const resubscribeToRooms = async () => {
        const metadata = getConnectionMetadata(ws);
        if (!metadata) return;

        const subscribedRooms = getSubscribedRooms(ws);
        if (subscribedRooms.length === 0) {
          return; // No rooms to resubscribe
        }

        logInfo('Resubscribing to rooms after reconnect', {
          userId,
          roomCount: subscribedRooms.length,
        });

        // Batch resubscribe (max 10 per batch)
        const batches = [];
        for (let i = 0; i < subscribedRooms.length; i += 10) {
          batches.push(subscribedRooms.slice(i, i + 10));
        }

        for (const batch of batches) {
          for (const roomId of batch) {
            try {
              const success = await registerWebSocketToRoom(ws, roomId);
              if (success) {
                addRoomSubscription(ws, roomId);
                logInfo('Room resubscribed', { userId, roomId });
              } else {
                logWarning('Failed to resubscribe to room', { userId, roomId });
              }
            } catch (err) {
              logError(
                'Error resubscribing to room',
                err instanceof Error ? err : new Error(String(err)),
                { userId, roomId }
              );
            }
          }
        }

        // Transition to SUBSCRIBED state after resubscription
        updateConnectionState(ws, ConnectionState.SUBSCRIBED);
        logInfo('Room resubscription complete', { userId, state: ConnectionState.SUBSCRIBED });
      };

      // Handle pong response
      ws.on('pong', () => {
        const now = Date.now();
        ws.alive = now;

        // Update pong timestamp in connection manager
        updatePingPong(ws, false);

        // Reset reconnect attempts on successful pong
        resetReconnectAttempts(ws);

        // Transition to AUTHENTICATED if still in CONNECTED state
        const metadata = getConnectionMetadata(ws);
        if (metadata && metadata.state === ConnectionState.CONNECTED) {
          updateConnectionState(ws, ConnectionState.AUTHENTICATED);
          logInfo('WebSocket authenticated', { userId, state: ConnectionState.AUTHENTICATED });

          // Trigger room resubscription
          resubscribeToRooms().catch((err) => {
            logError(
              'Failed to resubscribe to rooms',
              err instanceof Error ? err : new Error(String(err))
            );
          });
        }
      });

      // Handle incoming messages on this connection
      ws.on('message', async (data: Buffer) => {
        // Ensure protobuf schema is loaded (await if still loading)
        let schemaRoot: protobuf.Root;
        try {
          schemaRoot = await loadProto();
        } catch (err) {
          // Schema loading failed - reject message with error
          ws.send(JSON.stringify({ type: 'error', msg: 'proto not loaded' }));
          return;
        }

        // Look up the WSEnvelope type from loaded schema
        // 'sinaps.v1.WSEnvelope' is the fully qualified type name from .proto file
        const WSEnvelope = schemaRoot.lookupType('sinaps.v1.WSEnvelope');

        let envelope;
        try {
          // Decode binary protobuf message to JavaScript object
          // data is Buffer containing protobuf-encoded bytes
          envelope = WSEnvelope.decode(data);
        } catch (err) {
          // Decode failed - malformed message or wrong schema version
          ws.send(JSON.stringify({ type: 'error', msg: 'invalid envelope' }));
          return;
        }

        // Extract message type and room ID from decoded envelope
        const t = (envelope as any).type;
        const roomId = (envelope as any).room_id;

        // Register WebSocket to room for efficient broadcasting
        if (roomId && typeof roomId === 'string') {
          registerWebSocketToRoom(ws, roomId)
            .then((success) => {
              if (success) {
                // Track room subscription in connection manager
                addRoomSubscription(ws, roomId);
                logInfo('Room subscription tracked', { userId, roomId });
              }
            })
            .catch((err) => {
              logError(
                'Failed to register WebSocket to room',
                err instanceof Error ? err : new Error(String(err)),
                { userId, roomId }
              );
            });
        }

        // Route message to appropriate handler based on type
        switch (t) {
          case 'presence':
            // Presence updates (online/offline status)
            handlePresence(ws, envelope);
            break;
          case 'messaging':
            // Chat messages (async - handles rate limiting and moderation)
            handleMessaging(ws, envelope).catch((err) => {
              logError('Messaging handler error', err);
              ws.send(JSON.stringify({ type: 'error', msg: 'message_processing_failed' }));
            });
            break;
          case 'read_receipt':
            // Read receipts (delivered, read, seen)
            handleReadReceipt(ws, envelope);
            break;
          case 'delivery_ack':
            // Delivery acknowledgements from clients
            handleDeliveryAckMessage(ws, envelope).catch((err) => {
              logError('Delivery ack handler error', err);
              ws.send(JSON.stringify({ type: 'error', msg: 'delivery_ack_processing_failed' }));
            });
            break;
          default:
            // Unknown message type - send error back to client
            ws.send(JSON.stringify({ type: 'error', msg: 'unknown type' }));
            break;
        }
      });

      // Clean up when connection closes
      ws.on('close', (code, reason) => {
        // VALIDATION CHECKPOINT: Validate close code
        if (code !== 1000 && code !== 1001) {
          logError(
            'WebSocket closed with non-normal code',
            new Error(`Code: ${code}, Reason: ${reason.toString()}`),
            { userId, code, reason: reason.toString() }
          );
        }

        // Log disconnect event
        logInfo('WebSocket disconnected', { userId, code, reason: reason.toString() });

        if (ws.pingTimeout) {
          clearTimeout(ws.pingTimeout);
        }

        // Unregister from utils (room cleanup)
        unregisterWebSocket(ws).catch((err) => {
          logError(
            'Failed to unregister WebSocket on close',
            err instanceof Error ? err : new Error(String(err)),
            { userId }
          );
        });

        // Log connection quality metrics
        const metadata = getConnectionMetadata(ws);
        if (metadata) {
          const quality = getConnectionQuality();
          if (quality < 0.5 && metadata.pingLatencies.length > 0) {
            const avgLatency =
              metadata.pingLatencies.reduce((a, b) => a + b, 0) / metadata.pingLatencies.length;
            logError(
              'WebSocket connection quality was poor',
              new Error(`Quality: ${quality}, Avg Latency: ${avgLatency}ms`),
              { userId }
            );
          }

          // Log quality metrics to telemetry
          logConnectionQualityMetrics().catch(() => {
            // Non-critical: ignore telemetry errors
          });

          // Update state to DISCONNECTED
          updateConnectionState(ws, ConnectionState.DISCONNECTED);
        }

        // Clean up connection manager
        unregisterConnection(ws);
      });

      // Clean up on error
      ws.on('error', (error) => {
        const metadata = getConnectionMetadata(ws);
        const userId = metadata?.userId || 'unknown';

        // Log error with context
        logError('WebSocket error', error instanceof Error ? error : new Error(String(error)), {
          userId,
          state: metadata?.state,
          reconnectAttempts: metadata?.reconnectAttempts || 0,
        });

        // Increment reconnection attempts in connection manager
        const attempts = incrementReconnectAttempts(ws);

        // Calculate exponential backoff using connection manager
        const backoffDelay = calculateBackoffDelay(attempts);

        // VALIDATION CHECKPOINT: Validate reconnection backoff
        if (attempts > 5) {
          logWarning('WebSocket reconnection backoff', { userId, delay: backoffDelay, attempts });
        }

        // Log reconnect event
        logInfo('WebSocket reconnect event', { userId, backoffDelay, attempts });

        // Send reconnection guidance to client (if connection still open)
        if (ws.readyState === WebSocket.OPEN) {
          try {
            ws.send(
              JSON.stringify({
                type: 'reconnect_guidance',
                backoff_ms: backoffDelay,
                attempts: attempts,
                max_backoff_ms: parseInt(process.env.WS_EXPONENTIAL_MAX_MS || '30000', 10),
              })
            );
          } catch (sendError) {
            // Ignore send errors during error handling
            logWarning('Failed to send reconnect guidance', { userId });
          }
        }

        if (ws.pingTimeout) {
          clearTimeout(ws.pingTimeout);
        }

        // Unregister from utils (room cleanup)
        unregisterWebSocket(ws).catch((err) => {
          logError(
            'Failed to unregister WebSocket on error',
            err instanceof Error ? err : new Error(String(err)),
            { userId }
          );
        });

        // Update state to DISCONNECTED
        if (metadata) {
          updateConnectionState(ws, ConnectionState.DISCONNECTED);
        }
      });
    }
  );
}

/**
 * Setup Redis failover listeners for WebSocket connections
 * Handles Redis cluster/sentinel failover events
 */
function setupRedisFailoverListeners(): void {
  try {
    const subscriber = getRedisSubscriber();
    if (!subscriber) {
      logWarning('Redis subscriber not available for failover listeners');
      return;
    }

    // Listen for Redis reconnection events
    subscriber.on('reconnecting', (delay: number) => {
      logInfo('Redis failover detected - reconnecting', { delay });
      // Note: Room subscriptions will be automatically resubscribed via initializeRedisSubscriber
    });

    subscriber.on('ready', () => {
      logInfo('Redis reconnected after failover', {});
      // Room channels will be automatically resubscribed
    });

    subscriber.on('error', (err: Error) => {
      logError('Redis failover error', err);
    });

    // Cluster-specific failover events
    if ('on' in subscriber && typeof (subscriber as any).on === 'function') {
      // Check if this is a Cluster instance
      if ((subscriber as any).nodes) {
        (subscriber as any).on('+node', (node: any) => {
          logInfo('Redis cluster node added', {
            host: node.options?.host,
            port: node.options?.port,
          });
        });

        (subscriber as any).on('-node', (node: any) => {
          logWarning('Redis cluster node removed', {
            host: node.options?.host,
            port: node.options?.port,
          });
        });

        (subscriber as any).on('+move', (slot: number, node: any) => {
          logInfo('Redis cluster slot moved (failover)', {
            slot,
            host: node.options?.host,
            port: node.options?.port,
          });
        });
      }
    }

    logInfo('Redis failover listeners setup complete');
  } catch (error) {
    logError(
      'Failed to setup Redis failover listeners',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}
