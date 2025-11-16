/**
 * Redis Pub/Sub helpers for real-time events
 */

import { getRedisClient } from './db.js';
import { logError, logInfo } from '../shared/logger.js';

// Publisher instance (for sending messages to Redis channels)
// Uses regular Redis client (can publish and subscribe, but we separate for clarity)
const publisher = getRedisClient();

// Subscriber instance (separate connection for subscribing to channels)
// IMPORTANT: Redis requires separate connection for SUBSCRIBE mode
// A connection in SUBSCRIBE mode can only execute subscribe/unsubscribe commands
// So we need two connections: one for pub, one for sub
let subscriber: any = null;

export function getRedisPublisher(): any {
  return publisher;
}

export function getRedisSubscriber(): any {
  if (!subscriber) {
    // Create separate Redis connection for subscriber
    // Use require() instead of import to avoid TypeScript type conflicts with ioredis
    const Redis = require('ioredis');
    // VAULT NOT FEASIBLE: Performance blocker - Redis needed synchronously at startup
    // TODO: Move to vault when async initialization performance allows
    const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
    
    // Create subscriber with same retry strategy as main client
    subscriber = new Redis(redisUrl, {
      retryStrategy: (times: number) => {
        // Exponential backoff: 50ms, 100ms, 150ms... up to 2000ms max
        const delay = Math.min(times * 50, 2000);
        return delay;
      },
      maxRetriesPerRequest: 3, // Max 3 retries per command
    });

    // Error handler: log but don't crash (subscriber failures are non-fatal)
    subscriber.on('error', (err: Error) => {
      logError('Redis subscriber error', err);
    });

    // Connection success handler
    subscriber.on('connect', () => {
      logInfo('Redis subscriber connected');
    });
  }
  return subscriber;
}

// Export for convenience
export const redisPublisher = getRedisPublisher();
export const redisSubscriber = getRedisSubscriber();

/**
 * Handle database trigger events from PostgreSQL NOTIFY
 * Listens for pg_notify events and republishes to Redis channels
 * This bridges PostgreSQL triggers with Redis pub/sub for WebSocket broadcasting
 */
export function setupDatabaseTriggerHandlers(): void {
  // Note: PostgreSQL NOTIFY events are typically handled by Supabase Realtime
  // This function is a placeholder for custom Redis bridging if needed
  
  // In production, you might want to:
  // 1. Subscribe to PostgreSQL LISTEN channels
  // 2. Republish events to Redis for WebSocket broadcasting
  // 3. Handle event routing based on room_id
  
  logInfo('Database trigger handlers initialized (Supabase Realtime handles NOTIFY events)');
}

/**
 * Publish message event to Redis channel
 * Called by database triggers or application code
 * @param eventType - Type of event (message_created, message_updated, message_deleted)
 * @param roomId - Room ID
 * @param data - Event data
 */
export async function publishMessageEvent(
  eventType: 'message_created' | 'message_updated' | 'message_deleted',
  roomId: string,
  data: Record<string, any>
): Promise<void> {
  try {
    const channel = `room:${roomId}`;
    const payload = JSON.stringify({
      type: eventType,
      room_id: roomId,
      ...data,
      timestamp: Date.now(),
    });
    
    await redisPublisher.publish(channel, payload);
    logInfo(`Published ${eventType} event to Redis channel: ${channel}`);
  } catch (error) {
    logError(`Failed to publish ${eventType} event`, error instanceof Error ? error : new Error(String(error)));
  }
}

