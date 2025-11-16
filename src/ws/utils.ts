/**
 * WebSocket utility functions for broadcasting messages
 * 
 * Supports both Redis pub/sub (for multi-server deployments) and
 * direct WebSocket broadcasting (for single-server optimization)
 */

import { getRedisPublisher } from '../config/redis-pubsub.js';
import { WebSocket } from 'ws';
import { logInfo, logError } from '../shared/logger.js';

/**
 * Room-based WebSocket client mapping for efficient direct broadcasting
 * Maps roomId -> Set of WebSocket connections
 * Uses Set for iteration support, but ensures cleanup on connection close
 */
const roomClientMap = new Map<string, Set<WebSocket>>();

/**
 * Track which rooms each WebSocket connection is subscribed to
 * Maps WebSocket -> Set of roomIds
 */
const wsRoomMap = new WeakMap<WebSocket, Set<string>>();

/**
 * Register a WebSocket connection to a room
 * Used for efficient room-based broadcasting
 */
export function registerWebSocketToRoom(ws: WebSocket, roomId: string): void {
  // Add WebSocket to room's client set
  if (!roomClientMap.has(roomId)) {
    roomClientMap.set(roomId, new Set());
  }
  roomClientMap.get(roomId)!.add(ws);
  
  // Track room membership for this WebSocket (using WeakMap for automatic cleanup)
  if (!wsRoomMap.has(ws)) {
    wsRoomMap.set(ws, new Set());
  }
  wsRoomMap.get(ws)!.add(roomId);
  
  logInfo('WebSocket registered to room', { roomId });
}

/**
 * Unregister a WebSocket connection from a room
 * Called when connection closes or leaves room
 */
export function unregisterWebSocketFromRoom(ws: WebSocket, roomId: string): void {
  // Remove WebSocket from room's client set
  const clients = roomClientMap.get(roomId);
  if (clients) {
    clients.delete(ws);
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
  
  logInfo('WebSocket unregistered from room', { roomId });
}

/**
 * Unregister WebSocket from all rooms
 * Called when connection closes
 */
export function unregisterWebSocket(ws: WebSocket): void {
  const rooms = wsRoomMap.get(ws);
  if (rooms) {
    for (const roomId of rooms) {
      unregisterWebSocketFromRoom(ws, roomId);
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

/**
 * Process broadcast queue for a room (called periodically)
 */
function processBroadcastQueue(roomId: string): void {
  const queue = broadcastQueue.get(roomId);
  if (!queue || queue.length === 0) {
    return;
  }
  
  // Take up to BATCH_SIZE messages from queue
  const batch = queue.splice(0, BATCH_SIZE);
  const payload = JSON.stringify(batch.map(b => b.message));
  
  // Broadcast batch via direct WebSocket connections
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
          logError('Failed to send WebSocket batch', error instanceof Error ? error : new Error(errorMessage));
          unregisterWebSocketFromRoom(client, roomId);
        }
      } else {
        unregisterWebSocketFromRoom(client, roomId);
      }
    }
    
    if (sentCount > 0) {
      logInfo('Broadcasted batch via direct WebSocket', { roomId, batchSize: batch.length, sentCount });
      return;
    }
  }
  
  // Fallback to Redis pub/sub for the batch
  try {
    const publisher = getRedisPublisher();
    batch.forEach(({ message }) => {
      publisher.publish(`room:${roomId}`, JSON.stringify(message));
    });
    logInfo('Broadcasted batch via Redis pub/sub', { roomId, batchSize: batch.length });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError('Failed to broadcast batch via Redis', error instanceof Error ? error : new Error(errorMessage));
  }
}

/**
 * Broadcast a message to all clients in a room
 * Uses batching and backpressure to optimize performance
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
  // Add to broadcast queue for batching
  if (!broadcastQueue.has(roomId)) {
    broadcastQueue.set(roomId, []);
    // Schedule queue processing
    setTimeout(() => processBroadcastQueue(roomId), BATCH_INTERVAL_MS);
  }
  
  const queue = broadcastQueue.get(roomId)!;
  
  // Backpressure: drop messages if queue is too large
  if (queue.length >= MAX_QUEUE_SIZE) {
    logError('Broadcast queue full, dropping message', new Error(`Queue size: ${queue.length}`));
    return;
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
            logError('Failed to send WebSocket message', error instanceof Error ? error : new Error(errorMessage));
            unregisterWebSocketFromRoom(client, roomId);
          }
        } else {
          unregisterWebSocketFromRoom(client, roomId);
        }
      }
      
      if (sentCount > 0) {
        logInfo('Broadcasted via direct WebSocket', { roomId, sentCount });
        return; // Successfully sent via direct broadcast
      }
    }
  }
  
  // Fallback to Redis pub/sub (for multi-server or when direct broadcast fails)
  try {
    const publisher = getRedisPublisher();
    publisher.publish(`room:${roomId}`, JSON.stringify(message));
    logInfo('Broadcasted via Redis pub/sub', { roomId });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError('Failed to broadcast via Redis', error instanceof Error ? error : new Error(errorMessage));
  }
}

