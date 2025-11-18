/**
 * WebSocket Message Rate Limiter
 * Limits messages per user: max 15 messages per 30 seconds (configurable by tier)
 * Uses Redis for distributed rate limiting across multiple servers
 * Implements sliding window algorithm for accurate rate limiting
 */

import { getRedisClient } from '../config/db.ts';
import { logWarning, logInfo } from '../shared/logger.js';
import { getUserSubscription, SubscriptionTier } from '../services/subscription-service.js';

// Base rate limits (free tier)
const BASE_MAX_MESSAGES = 15;
const WINDOW_SECONDS = 30;

// Tier-based rate limit multipliers
const TIER_LIMITS: Record<SubscriptionTier, number> = {
  [SubscriptionTier.FREE]: 15, // 15 messages per 30 seconds
  [SubscriptionTier.PRO]: 50, // 50 messages per 30 seconds
  [SubscriptionTier.TEAM]: 200, // 200 messages per 30 seconds (enterprise)
};

interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
  reason?: string;
}

/**
 * Check if user can send a message (rate limit check)
 * Returns rate limit status with remaining count and reset time
 * Uses sliding window algorithm for accurate rate limiting
 */
export async function checkMessageRateLimit(
  userId: string,
  roomId: string
): Promise<RateLimitResult> {
  try {
    const redis = getRedisClient();
    const now = Date.now();
    const windowMs = WINDOW_SECONDS * 1000;

    // Get user tier for tier-based limits
    const tier = await getUserSubscription(userId);
    const maxMessages = TIER_LIMITS[tier] || BASE_MAX_MESSAGES;

    // Use sliding window key pattern: ws:msg:rate:sliding:{userId}:{roomId}
    const key = `ws:msg:rate:sliding:${userId}:${roomId}`;
    const sortedSetKey = `${key}:timestamps`;

    if (redis) {
      // Sliding window algorithm using Redis sorted sets
      // Store timestamps as scores in sorted set
      const windowStart = now - windowMs;

      // Remove old entries outside the window
      await redis.zremrangebyscore(sortedSetKey, 0, windowStart);

      // Count messages in current window
      const count = await redis.zcard(sortedSetKey);

      // Check if limit exceeded
      if (count >= maxMessages) {
        // Get oldest timestamp to calculate reset time
        const oldestTimestamps = await redis.zrange(sortedSetKey, 0, 0, 'WITHSCORES');
        const oldestTimestamp = oldestTimestamps.length > 0 ? parseInt(oldestTimestamps[1]) : now;
        const resetAt = new Date(oldestTimestamp + windowMs);

        logWarning(`Message rate limit exceeded: user ${userId} (tier: ${tier}) in room ${roomId}`);
        return {
          allowed: false,
          remaining: 0,
          resetAt,
          reason: `Rate limit exceeded: max ${maxMessages} messages per ${WINDOW_SECONDS} seconds`,
        };
      }

      // Add current message timestamp to sorted set
      await redis.zadd(sortedSetKey, now, `${now}-${Math.random()}`);

      // Set expiry on sorted set (cleanup after window + 1 second)
      await redis.expire(sortedSetKey, WINDOW_SECONDS + 1);

      // Calculate remaining messages
      const remaining = Math.max(0, maxMessages - count - 1);

      // Calculate reset time (when oldest message expires)
      const oldestTimestamps = await redis.zrange(sortedSetKey, 0, 0, 'WITHSCORES');
      const oldestTimestamp = oldestTimestamps.length > 0 ? parseInt(oldestTimestamps[1]) : now;
      const resetAt = new Date(oldestTimestamp + windowMs);

      return {
        allowed: true,
        remaining,
        resetAt,
      };
    } else {
      // Fallback to memory store if Redis unavailable
      // Note: This won't work across multiple servers, but prevents crashes
      const memoryKey = `ws:msg:rate:${userId}:${roomId}`;
      const memoryStore: Record<string, { timestamps: number[]; resetAt: number }> = {};

      const store = memoryStore[memoryKey];
      const windowStart = now - windowMs;

      if (!store || store.resetAt < now) {
        // New window
        memoryStore[memoryKey] = {
          timestamps: [now],
          resetAt: now + windowMs,
        };
        return {
          allowed: true,
          remaining: maxMessages - 1,
          resetAt: new Date(now + windowMs),
        };
      }

      // Remove old timestamps outside window (sliding window)
      store.timestamps = store.timestamps.filter((ts) => ts > windowStart);

      // Check if limit exceeded
      if (store.timestamps.length >= maxMessages) {
        logWarning(
          `Message rate limit exceeded (memory): user ${userId} (tier: ${tier}) in room ${roomId}`
        );
        const oldestTimestamp = Math.min(...store.timestamps);
        return {
          allowed: false,
          remaining: 0,
          resetAt: new Date(oldestTimestamp + windowMs),
          reason: `Rate limit exceeded: max ${maxMessages} messages per ${WINDOW_SECONDS} seconds`,
        };
      }

      // Add current timestamp
      store.timestamps.push(now);
      const oldestTimestamp = Math.min(...store.timestamps);
      const resetAt = new Date(oldestTimestamp + windowMs);

      return {
        allowed: true,
        remaining: maxMessages - store.timestamps.length,
        resetAt,
      };
    }
  } catch (error: any) {
    logWarning('Rate limit check failed, allowing message', error);
    // Fail open - allow message if rate limit check fails
    const tier = await getUserSubscription(userId).catch(() => SubscriptionTier.FREE);
    const maxMessages = TIER_LIMITS[tier] || BASE_MAX_MESSAGES;
    return {
      allowed: true,
      remaining: maxMessages,
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
        // Delete both the old key format and new sliding window keys
        await redis.del(`ws:msg:rate:${userId}:${roomId}`);
        await redis.del(`ws:msg:rate:sliding:${userId}:${roomId}`);
        await redis.del(`ws:msg:rate:sliding:${userId}:${roomId}:timestamps`);
      } else {
        // Reset all rooms for user
        const keys = await redis.keys(`ws:msg:rate:${userId}:*`);
        if (keys.length > 0) {
          await redis.del(...keys);
        }
        const slidingKeys = await redis.keys(`ws:msg:rate:sliding:${userId}:*`);
        if (slidingKeys.length > 0) {
          await redis.del(...slidingKeys);
        }
      }
      logInfo(`Rate limit reset for user ${userId}${roomId ? ` in room ${roomId}` : ''}`);
    }
  } catch (error: any) {
    logWarning('Failed to reset rate limit', error);
  }
}
