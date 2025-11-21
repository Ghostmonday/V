/**
 * Redis Pub/Sub helpers for real-time events
 * Supports Redis Cluster and Sentinel modes for high availability
 */

import { getRedisClient } from './database-config.js';
import { createRedisClient, parseRedisConfig, type RedisClusterConfig } from './redis-cluster.js';
import { logError, logInfo, logWarning } from '../shared/logger-shared.js';
import Redis, { Cluster } from 'ioredis';

// Publisher instance (for sending messages to Redis channels)
// Uses regular Redis client (can publish and subscribe, but we separate for clarity)
// Supports cluster and sentinel modes
const publisher = getRedisClient();

// Subscriber instance (separate connection for subscribing to channels)
// IMPORTANT: Redis requires separate connection for SUBSCRIBE mode
// A connection in SUBSCRIBE mode can only execute subscribe/unsubscribe commands
// So we need two connections: one for pub, one for sub
// Supports cluster and sentinel modes
let subscriber: Redis | Cluster | null = null;

export function getRedisPublisher(): Redis | Cluster {
  return publisher;
}

export function getRedisSubscriber(): Redis | Cluster {
  if (!subscriber) {
    try {
      // Parse configuration from environment (same as main client)
      const redisConfig = parseRedisConfig();

      // Create subscriber with same configuration as publisher
      // This ensures both connections use the same cluster/sentinel setup
      subscriber = createRedisClient(redisConfig);

      // Error handler: log but don't crash (subscriber failures are non-fatal)
      subscriber.on('error', (err: Error) => {
        logError('Redis subscriber error', err);
      });

      // Connection success handler
      subscriber.on('connect', () => {
        logInfo(`Redis subscriber connected (${redisConfig.mode} mode)`);
      });

      // Reconnection handler
      subscriber.on('reconnecting', (delay: number) => {
        logInfo(`Redis subscriber reconnecting in ${delay}ms`);
      });

      // Close handler
      subscriber.on('close', () => {
        logWarning('Redis subscriber connection closed');
      });
    } catch (error) {
      logError(
        'Failed to initialize Redis subscriber',
        error instanceof Error ? error : new Error(String(error))
      );
      // Fallback to single instance mode
      const Redis = require('ioredis');
      const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
      subscriber = new Redis(redisUrl, {
        retryStrategy: (times: number) => Math.min(times * 50, 2000),
        maxRetriesPerRequest: 3,
      });
      logWarning('Using fallback single-instance Redis subscriber');
    }
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
    logError(
      `Failed to publish ${eventType} event`,
      error instanceof Error ? error : new Error(String(error))
    );
  }
}
