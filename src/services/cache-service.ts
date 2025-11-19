/**
 * Redis Caching Service
 * Provides caching layer for frequently accessed data
 * Implements TTL-based expiration and smart invalidation
 */

import { getRedisClient } from '../config/database-config.js';
import { logError, logInfo } from '../shared/logger-shared.js';

const redis = getRedisClient();
const DEFAULT_TTL = 30; // 30 seconds default TTL

interface CacheOptions {
  ttl?: number; // Time to live in seconds
  keyPrefix?: string; // Key prefix for namespacing
}

/**
 * Get cached value
 */
export async function getCache<T>(key: string, options?: CacheOptions): Promise<T | null> {
  try {
    const cacheKey = options?.keyPrefix ? `${options.keyPrefix}:${key}` : key;
    const cached = await redis.get(cacheKey);
    
    if (cached) {
      return JSON.parse(cached) as T;
    }
    
    return null;
  } catch (error) {
    logError('Cache get error', error instanceof Error ? error : new Error(String(error)));
    return null; // Fail open - return null on cache error
  }
}

/**
 * Set cached value
 */
export async function setCache<T>(
  key: string,
  value: T,
  options?: CacheOptions
): Promise<boolean> {
  try {
    const cacheKey = options?.keyPrefix ? `${options.keyPrefix}:${key}` : key;
    const ttl = options?.ttl || DEFAULT_TTL;
    const serialized = JSON.stringify(value);
    
    await redis.setex(cacheKey, ttl, serialized);
    return true;
  } catch (error) {
    logError('Cache set error', error instanceof Error ? error : new Error(String(error)));
    return false; // Fail open - return false on cache error
  }
}

/**
 * Delete cached value
 */
export async function deleteCache(key: string, options?: CacheOptions): Promise<boolean> {
  try {
    const cacheKey = options?.keyPrefix ? `${options.keyPrefix}:${key}` : key;
    await redis.del(cacheKey);
    return true;
  } catch (error) {
    logError('Cache delete error', error instanceof Error ? error : new Error(String(error)));
    return false;
  }
}

/**
 * Invalidate cache by pattern (e.g., "room:*")
 */
export async function invalidateCachePattern(pattern: string): Promise<number> {
  try {
    const keys = await redis.keys(pattern);
    if (keys.length === 0) return 0;
    
    const deleted = await redis.del(...keys);
    logInfo(`Invalidated ${deleted} cache keys matching pattern: ${pattern}`);
    return deleted;
  } catch (error) {
    logError('Cache invalidation error', error instanceof Error ? error : new Error(String(error)));
    return 0;
  }
}

/**
 * Cache wrapper for async functions
 * Automatically caches result and handles cache misses
 */
export async function cached<T>(
  key: string,
  fn: () => Promise<T>,
  options?: CacheOptions
): Promise<T> {
  // Try cache first
  const cached = await getCache<T>(key, options);
  if (cached !== null) {
    return cached;
  }
  
  // Cache miss - execute function
  const result = await fn();
  
  // Cache result
  await setCache(key, result, options);
  
  return result;
}

// Cache key generators
export const CacheKeys = {
  roomList: (userId?: string) => userId ? `room:list:${userId}` : 'room:list:all',
  room: (roomId: string) => `room:${roomId}`,
  messages: (roomId: string, since?: string) => 
    since ? `messages:${roomId}:${since}` : `messages:${roomId}:latest`,
  user: (userId: string) => `user:${userId}`,
};

// Cache invalidation helpers
export async function invalidateRoomCache(roomId: string): Promise<void> {
  await Promise.all([
    deleteCache(CacheKeys.room(roomId)),
    invalidateCachePattern('room:list:*'), // Invalidate all room lists
  ]);
}

export async function invalidateMessageCache(roomId: string): Promise<void> {
  await invalidateCachePattern(`messages:${roomId}:*`);
}

export async function invalidateUserCache(userId: string): Promise<void> {
  await deleteCache(CacheKeys.user(userId));
}

/**
 * Warm cache (alias for cached function)
 * Used by room-service.ts
 */
export async function warmCache<T>(
  key: string,
  fn: () => Promise<T>,
  ttl?: number
): Promise<T> {
  return cached(key, fn, { ttl });
}

/**
 * Invalidate cache pattern (alias)
 * Used by room-service.ts
 */
export async function invalidatePattern(pattern: string): Promise<number> {
  return invalidateCachePattern(pattern);
}
