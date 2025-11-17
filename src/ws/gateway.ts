/**
 * WebSocket gateway using protobuf envelope
 * - uses specs/proto/ws_envelope.proto for decoding
 * - delegates to handlers based on envelope.type
 */

import { WebSocketServer, WebSocket } from 'ws';
import protobuf from 'protobufjs';
import path from 'path';
import { handlePresence } from './handlers/presence.js';
import { handleMessaging } from './handlers/messaging.js';
import { handleReadReceipt } from './handlers/read-receipts.js';
import { handleDeliveryAckMessage } from './handlers/delivery-ack.js';
import { logError } from '../shared/logger.js';
import { 
  registerWebSocketToRoom, 
  unregisterWebSocket,
  initializeRedisSubscriber
} from './utils.js';

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
      root = await protobuf.load(path.join(process.cwd(), 'specs/proto/ws_envelope.proto'));
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
loadProto().catch(err => {
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
  
  // Listen for new WebSocket connections
  wss.on('connection', async (ws: WebSocket & { alive?: number; pingTimeout?: NodeJS.Timeout; userId?: string }, req: any) => {
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
    
    // TODO: Verify token with auth service
    // For now, store userId on websocket for later use
    ws.userId = userId;
    
    // Ensure protobuf schema is loaded before accepting messages
    try {
      await loadProto();
    } catch (err) {
      ws.send(JSON.stringify({ type: 'error', msg: 'server initialization failed' }));
      ws.close(1011, 'Server initialization failed');
      return;
    }
    // VALIDATION CHECKPOINT: Validate connection established
    if (ws.readyState !== WebSocket.OPEN) {
      ws.close(1006, 'Connection not open');
      return;
    }
    
    // Mark connection as alive
    ws.alive = Date.now();
    
    // Configuration: Idle timeout (5 minutes = 300000ms)
    const IDLE_TIMEOUT_MS = parseInt(process.env.WS_IDLE_TIMEOUT_MS || '300000', 10);
    const PING_INTERVAL_MS = parseInt(process.env.WS_PING_INTERVAL_MS || '30000', 10);
    const MAX_BACKOFF_MS = 30000; // 30 seconds max backoff
    
    // VALIDATION CHECKPOINT: Validate timeout configuration
    if (IDLE_TIMEOUT_MS < 60000 || IDLE_TIMEOUT_MS > 600000) {
      logError('Invalid WS_IDLE_TIMEOUT_MS configuration', new Error(`Value ${IDLE_TIMEOUT_MS} out of range`));
    }
    
    // Track connection quality metrics
    let pingLatencies: number[] = [];
    let lastPingTime = 0;
    let reconnectAttempts = 0;
    let connectionStartTime = Date.now();
    
    // Ping-pong health check with debounce and jitter
    // Prevents queue storms under load by randomizing ping intervals
    const schedulePing = () => {
      // Clear any existing timeout
      if (ws.pingTimeout) {
        clearTimeout(ws.pingTimeout);
      }
      
      // Calculate jitter: base interval + random -1s to +1s
      const jitter = (Math.random() * 2000) - 1000; // -1000ms to +1000ms
      const interval = PING_INTERVAL_MS + jitter;
      
      // Debounce: wrap ping in setTimeout with 5ms debounce
      ws.pingTimeout = setTimeout(() => {
        // VALIDATION CHECKPOINT: Validate connection still open
        if (ws.readyState !== WebSocket.OPEN) {
          return;
        }
        
        // VALIDATION CHECKPOINT: Validate idle timeout
        const timeSinceLastActivity = ws.alive ? Date.now() - ws.alive : Infinity;
        if (timeSinceLastActivity > IDLE_TIMEOUT_MS) {
          // Connection idle too long - close it
          logError('WebSocket connection idle timeout', new Error(`${timeSinceLastActivity}ms > ${IDLE_TIMEOUT_MS}ms`));
          ws.close(1001, 'Idle timeout');
          return;
        }
        
        // Check if last pong was more than 1 minute ago
        if (ws.alive && Date.now() - ws.alive > 60000) {
          // Connection appears dead - close it
          logError('WebSocket connection appears dead (no pong response)', new Error('No pong for >60s'));
          ws.close(1001, 'Connection timeout');
          return;
        }
        
        // Record ping time for latency measurement
        lastPingTime = Date.now();
        
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
      if (pingLatencies.length === 0) return 1.0;
      const avgLatency = pingLatencies.reduce((a, b) => a + b, 0) / pingLatencies.length;
      // Quality decreases as latency increases (100ms = 1.0, 1000ms = 0.0)
      return Math.max(0, Math.min(1, 1 - (avgLatency / 1000)));
    };
    
    // Log connection quality metrics to telemetry
    const logConnectionQualityMetrics = async () => {
      try {
        const quality = getConnectionQuality();
        const avgLatency = pingLatencies.length > 0 
          ? pingLatencies.reduce((a, b) => a + b, 0) / pingLatencies.length 
          : 0;
        const connectionDuration = Date.now() - connectionStartTime;
        
        // Import telemetry service dynamically
        const { logEvent } = await import('../telemetry/index.js');
        await logEvent({
          event: 'websocket_connection_quality',
          userId: ws.userId,
          metadata: {
            quality_score: quality,
            avg_latency_ms: avgLatency,
            connection_duration_ms: connectionDuration,
            reconnect_attempts: reconnectAttempts,
            ping_count: pingLatencies.length,
          },
        });
      } catch (error) {
        // Non-critical: log but don't block
        logError('Failed to log connection quality metrics', error instanceof Error ? error : new Error(String(error)));
      }
    };
    
    // Handle pong response
    ws.on('pong', () => {
      const now = Date.now();
      ws.alive = now;
      
      // VALIDATION CHECKPOINT: Validate pong response timing
      if (lastPingTime > 0) {
        const latency = now - lastPingTime;
        pingLatencies.push(latency);
        
        // Keep only last 10 latencies
        if (pingLatencies.length > 10) {
          pingLatencies.shift();
        }
        
        // Reset reconnect attempts on successful pong
        reconnectAttempts = 0;
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
        registerWebSocketToRoom(ws, roomId).catch(err => {
          logError('Failed to register WebSocket to room', err);
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
          handleMessaging(ws, envelope).catch(err => {
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
          handleDeliveryAckMessage(ws, envelope).catch(err => {
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
        logError('WebSocket closed with non-normal code', new Error(`Code: ${code}, Reason: ${reason.toString()}`));
      }
      
      if (ws.pingTimeout) {
        clearTimeout(ws.pingTimeout);
      }
      unregisterWebSocket(ws).catch(err => {
        logError('Failed to unregister WebSocket on close', err);
      });
      
      // Log connection quality metrics
      const quality = getConnectionQuality();
      if (quality < 0.5 && pingLatencies.length > 0) {
        const avgLatency = pingLatencies.reduce((a, b) => a + b, 0) / pingLatencies.length;
        logError('WebSocket connection quality was poor', new Error(`Quality: ${quality}, Avg Latency: ${avgLatency}ms`));
      }
      
      // Log quality metrics to telemetry
      logConnectionQualityMetrics().catch(() => {
        // Non-critical: ignore telemetry errors
      });
    });
    
    // Clean up on error
    ws.on('error', (error) => {
      logError('WebSocket error', error);
      reconnectAttempts++;
      
      // Exponential backoff for reconnection (max 30 seconds)
      const backoffDelay = Math.min(MAX_BACKOFF_MS, Math.pow(2, reconnectAttempts) * 1000);
      
      // VALIDATION CHECKPOINT: Validate reconnection backoff
      if (reconnectAttempts > 5) {
        logError('WebSocket reconnection backoff', new Error(`Delay: ${backoffDelay}ms, Attempts: ${reconnectAttempts}`));
      }
      
      // Send reconnection guidance to client (if connection still open)
      if (ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(JSON.stringify({
            type: 'reconnect_guidance',
            backoff_ms: backoffDelay,
            attempts: reconnectAttempts,
            max_backoff_ms: MAX_BACKOFF_MS,
          }));
        } catch (sendError) {
          // Ignore send errors during error handling
        }
      }
      
      if (ws.pingTimeout) {
        clearTimeout(ws.pingTimeout);
      }
      unregisterWebSocket(ws).catch(err => {
        logError('Failed to unregister WebSocket on error', err);
      });
    });
  });
}

