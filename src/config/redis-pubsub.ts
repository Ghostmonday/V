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

