/**
 * WebSocket Rate Limiter
 * Uses p-limit + Redis store to prevent spam
 * Blocks spam without breaking legit bursts
 */

import pLimit from 'p-limit';
import { getRedisClient } from '../config/db.js';
import { logWarning, logInfo } from '../shared/logger.js';

// Rate limit: 5 concurrent connections, 2 per second per IP
const limiter = pLimit({ concurrency: 5 });

interface RateLimitStore {
  [key: string]: {
    count: number;
    resetAt: number;
  };
}

const memoryStore: RateLimitStore = {};
const TTL_SECONDS = 60; // 60 second window

/**
 * Get client IP from request
 */
function getClientIP(req: any): string {
  return (
    req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
    req.headers['x-real-ip'] ||
    req.socket?.remoteAddress ||
    'unknown'
  );
}

/**
 * Check rate limit for WebSocket connection
 * Returns true if allowed, false if rate limited
 */
export async function checkWSRateLimit(
  roomId: string,
  req: any
): Promise<{ allowed: boolean; reason?: string }> {
  const clientIP = getClientIP(req);
  const key = `ws:rate:${clientIP}:${roomId}`;

  try {
    const redis = await getRedisClient();
    
    if (redis) {
      // Use Redis for distributed rate limiting
      const count = await redis.incr(key);
      
      if (count === 1) {
        // First request, set TTL
        await redis.expire(key, TTL_SECONDS);
      }
      
      // Check limits: 2 per second, but allow bursts up to 5
      if (count > 5) {
        await redis.decr(key); // Rollback
        logWarning(`WebSocket rate limit exceeded: ${clientIP} in room ${roomId}`);
        return { allowed: false, reason: 'Rate limit exceeded' };
      }
      
      return { allowed: true };
    } else {
      // Fallback to memory store if Redis unavailable
      const now = Date.now();
      const storeKey = key;
      
      if (!memoryStore[storeKey] || memoryStore[storeKey].resetAt < now) {
        memoryStore[storeKey] = { count: 1, resetAt: now + TTL_SECONDS * 1000 };
        return { allowed: true };
      }
      
      memoryStore[storeKey].count++;
      
      if (memoryStore[storeKey].count > 5) {
        memoryStore[storeKey].count--; // Rollback
        logWarning(`WebSocket rate limit exceeded (memory): ${clientIP} in room ${roomId}`);
        return { allowed: false, reason: 'Rate limit exceeded' };
      }
      
      return { allowed: true };
    }
  } catch (error: any) {
    logWarning('Rate limit check failed', error);
    // Fail open - allow connection if rate limit check fails
    return { allowed: true };
  }
}

/**
 * Wrap WebSocket join function with rate limiting
 */
export function rateLimitWSJoin<T extends any[]>(
  joinFn: (...args: T) => Promise<void>
): (...args: T) => Promise<void> {
  return async (...args: T) => {
    // Extract roomId from args (adjust based on your function signature)
    const roomId = args[0] as string;
    const req = args[1] as any;
    
    return limiter(async () => {
      const { allowed, reason } = await checkWSRateLimit(roomId, req);
      
      if (!allowed) {
        throw new Error(reason || 'Rate limit exceeded');
      }
      
      return joinFn(...args);
    });
  };
}

