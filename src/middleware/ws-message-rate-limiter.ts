/**
 * WebSocket Message Rate Limiter
 * Limits messages per user: max 15 messages per 30 seconds
 * Uses Redis for distributed rate limiting across multiple servers
 */

import { getRedisClient } from '../config/db.js';
import { logWarning } from '../shared/logger.js';

const MAX_MESSAGES = 15;
const WINDOW_SECONDS = 30;

interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
  reason?: string;
}

/**
 * Check if user can send a message (rate limit check)
 * Returns rate limit status with remaining count and reset time
 */
export async function checkMessageRateLimit(
  userId: string,
  roomId: string
): Promise<RateLimitResult> {
  try {
    const redis = getRedisClient();
    const key = `ws:msg:rate:${userId}:${roomId}`;
    const now = Date.now();
    const windowMs = WINDOW_SECONDS * 1000;

    if (redis) {
      // Use Redis for distributed rate limiting
      const count = await redis.incr(key);
      
      // Set expiry on first request
      if (count === 1) {
        await redis.expire(key, WINDOW_SECONDS);
      }

      // Check if limit exceeded
      if (count > MAX_MESSAGES) {
        await redis.decr(key); // Rollback increment
        
        // Get TTL to calculate reset time
        const ttl = await redis.ttl(key);
        const resetAt = new Date(now + (ttl * 1000));
        
        logWarning(`Message rate limit exceeded: user ${userId} in room ${roomId}`);
        return {
          allowed: false,
          remaining: 0,
          resetAt,
          reason: `Rate limit exceeded: max ${MAX_MESSAGES} messages per ${WINDOW_SECONDS} seconds`,
        };
      }

      // Get TTL for reset time
      const ttl = await redis.ttl(key);
      const resetAt = new Date(now + (ttl * 1000));
      const remaining = Math.max(0, MAX_MESSAGES - count);

      return {
        allowed: true,
        remaining,
        resetAt,
      };
    } else {
      // Fallback to memory store if Redis unavailable
      // Note: This won't work across multiple servers, but prevents crashes
      const memoryKey = `ws:msg:rate:${userId}:${roomId}`;
      const memoryStore: Record<string, { count: number; resetAt: number }> = {};
      
      const now = Date.now();
      const store = memoryStore[memoryKey];

      if (!store || store.resetAt < now) {
        // New window
        memoryStore[memoryKey] = {
          count: 1,
          resetAt: now + windowMs,
        };
        return {
          allowed: true,
          remaining: MAX_MESSAGES - 1,
          resetAt: new Date(now + windowMs),
        };
      }

      store.count++;
      
      if (store.count > MAX_MESSAGES) {
        store.count--; // Rollback
        logWarning(`Message rate limit exceeded (memory): user ${userId} in room ${roomId}`);
        return {
          allowed: false,
          remaining: 0,
          resetAt: new Date(store.resetAt),
          reason: `Rate limit exceeded: max ${MAX_MESSAGES} messages per ${WINDOW_SECONDS} seconds`,
        };
      }

      return {
        allowed: true,
        remaining: MAX_MESSAGES - store.count,
        resetAt: new Date(store.resetAt),
      };
    }
  } catch (error: any) {
    logWarning('Rate limit check failed, allowing message', error);
    // Fail open - allow message if rate limit check fails
    return {
      allowed: true,
      remaining: MAX_MESSAGES,
      resetAt: new Date(Date.now() + WINDOW_SECONDS * 1000),
    };
  }
}

/**
 * Reset rate limit for a user (admin function)
 */
export async function resetUserRateLimit(userId: string, roomId?: string): Promise<void> {
  try {
    const redis = getRedisClient();
    if (redis) {
      if (roomId) {
        await redis.del(`ws:msg:rate:${userId}:${roomId}`);
      } else {
        // Reset all rooms for user
        const keys = await redis.keys(`ws:msg:rate:${userId}:*`);
        if (keys.length > 0) {
          await redis.del(...keys);
        }
      }
    }
  } catch (error: any) {
    logWarning('Failed to reset rate limit', error);
  }
}

