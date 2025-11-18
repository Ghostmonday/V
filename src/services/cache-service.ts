/**
 * Cache Service
 * Provides Redis-based caching with invalidation strategies and metrics
 */

import { getRedisClient } from '../config/db.ts';
import { logInfo, logError } from '../shared/logger.js';
import { createHash } from 'crypto';

const redis = getRedisClient();

// Cache metrics
const cacheMetrics = {
  hits: 0,
  misses: 0,
  sets: 0,
  deletes: 0,
};

/**
 * Generate ETag for content
 * @param content - Content to generate ETag for
 * @returns ETag string
 */
export function generateETag(content: any): string {
  const contentStr = typeof content === 'string' ? content : JSON.stringify(content);
  return `"${createHash('md5').update(contentStr).digest('hex')}"`;
}

/**
 * Get cached value
 * @param key - Cache key
 * @returns Cached value or null
 */
export async function getCached(key: string): Promise<any | null> {
  try {
    const cached = await redis.get(key);
    if (cached) {
      cacheMetrics.hits++;
      return JSON.parse(cached);
    }
    cacheMetrics.misses++;
    return null;
  } catch (error) {
    logError(
      `Cache get error for key: ${key}`,
      error instanceof Error ? error : new Error(String(error))
    );
    cacheMetrics.misses++;
    return null;
  }
}

/**
 * Set cached value
 * @param key - Cache key
 * @param value - Value to cache
 * @param ttlSeconds - Time to live in seconds (default: 300 = 5 minutes)
 */
export async function setCached(key: string, value: any, ttlSeconds: number = 300): Promise<void> {
  try {
    const serialized = JSON.stringify(value);
    await redis.setex(key, ttlSeconds, serialized);
    cacheMetrics.sets++;
  } catch (error) {
    logError(
      `Cache set error for key: ${key}`,
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Delete cached value
 * @param key - Cache key to delete
 */
export async function deleteCached(key: string): Promise<void> {
  try {
    await redis.del(key);
    cacheMetrics.deletes++;
  } catch (error) {
    logError(
      `Cache delete error for key: ${key}`,
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Invalidate cache by pattern
 * @param pattern - Redis key pattern (e.g., 'user:*')
 */
export async function invalidatePattern(pattern: string): Promise<number> {
  try {
    const keys = await redis.keys(pattern);
    if (keys.length === 0) {
      return 0;
    }

    const deleted = await redis.del(...keys);
    cacheMetrics.deletes += deleted;
    return deleted;
  } catch (error) {
    logError(
      `Cache invalidation error for pattern: ${pattern}`,
      error instanceof Error ? error : new Error(String(error))
    );
    return 0;
  }
}

/**
 * Warm cache with frequently accessed data
 * @param key - Cache key
 * @param fetcher - Function to fetch data if not cached
 * @param ttlSeconds - Time to live in seconds
 */
export async function warmCache<T>(
  key: string,
  fetcher: () => Promise<T>,
  ttlSeconds: number = 300
): Promise<T> {
  const cached = await getCached(key);
  if (cached !== null) {
    return cached as T;
  }

  const data = await fetcher();
  await setCached(key, data, ttlSeconds);
  return data;
}

/**
 * Get cache metrics
 * @returns Cache hit/miss statistics
 */
export function getCacheMetrics(): {
  hits: number;
  misses: number;
  sets: number;
  deletes: number;
  hitRate: number;
} {
  const total = cacheMetrics.hits + cacheMetrics.misses;
  const hitRate = total > 0 ? cacheMetrics.hits / total : 0;

  return {
    ...cacheMetrics,
    hitRate: Math.round(hitRate * 100) / 100, // Round to 2 decimal places
  };
}

/**
 * Reset cache metrics
 */
export function resetCacheMetrics(): void {
  cacheMetrics.hits = 0;
  cacheMetrics.misses = 0;
  cacheMetrics.sets = 0;
  cacheMetrics.deletes = 0;
}
