import { Request, Response, NextFunction } from 'express';
import {
  getCached,
  setCached,
  generateETag,
  invalidatePattern,
} from '../../services/cache-service.js';
import { getRedisClient } from '../../config/db.ts';

const redis = getRedisClient();

export interface CacheOptions {
  prefix: string;
  ttlSeconds?: number; // Time to live in seconds
  varyBy?: string[]; // Headers to vary cache by (e.g., ['authorization'])
  skipCache?: (req: Request) => boolean; // Function to skip caching for specific requests
}

/**
 * Enhanced cache middleware with invalidation and cache warming
 */
export function cacheMiddleware(options: CacheOptions | string) {
  const opts: CacheOptions = typeof options === 'string' ? { prefix: options } : options;

  const {
    prefix,
    ttlSeconds = 300, // Default: 5 minutes
    varyBy = [],
    skipCache = () => false,
  } = opts;

  return async (req: Request, res: Response, next: NextFunction) => {
    // Skip caching if requested
    if (skipCache(req)) {
      return next();
    }

    // Build cache key with URL and varying headers
    const varyValues = varyBy.map((header) => req.headers[header.toLowerCase()] || '').join(':');
    const key = `${prefix}:${req.url}:${varyValues}`;

    // Check cache
    const cached = await getCached(key);
    if (cached) {
      const etag = generateETag(cached);

      // Handle If-None-Match header (304 Not Modified)
      if (req.headers['if-none-match'] === etag) {
        res.set('ETag', etag);
        return res.status(304).end();
      }

      res.set('ETag', etag);
      res.set('X-Cache', 'HIT');
      return res.json(cached);
    }

    // Cache miss - store key for later setting
    res.locals.cacheKey = key;
    res.locals.cacheTTL = ttlSeconds;
    res.set('X-Cache', 'MISS');

    // Intercept response to cache it
    const originalJson = res.json.bind(res);
    res.json = function (body: any) {
      // Only cache successful responses
      if (res.statusCode >= 200 && res.statusCode < 300) {
        setCached(key, body, ttlSeconds).catch((err) => {
          // Non-critical: log but don't fail request
          console.error('Failed to cache response:', err);
        });
      }
      return originalJson(body);
    };

    next();
  };
}

/**
 * Cache invalidation middleware
 * Invalidates cache based on request patterns
 */
export function cacheInvalidationMiddleware(pattern: string) {
  return async (req: Request, res: Response, next: NextFunction) => {
    // Invalidate cache after successful mutation operations
    const originalJson = res.json.bind(res);
    res.json = function (body: any) {
      if (
        res.statusCode >= 200 &&
        res.statusCode < 300 &&
        ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)
      ) {
        invalidatePattern(pattern).catch((err) => {
          console.error('Failed to invalidate cache:', err);
        });
      }
      return originalJson(body);
    };

    next();
  };
}

/**
 * Subscribe to Redis cache invalidation events
 * Listens for cache invalidation commands via Redis streams
 */
export function setupCacheInvalidationListener(): void {
  // Subscribe to cache invalidation channel
  const subscriber = redis.duplicate();

  subscriber.on('message', async (channel: string, message: string) => {
    if (channel === 'cache:invalidate') {
      try {
        const { pattern } = JSON.parse(message);
        await invalidatePattern(pattern);
        console.log(`Cache invalidated for pattern: ${pattern}`);
      } catch (error) {
        console.error('Failed to process cache invalidation:', error);
      }
    }
  });

  subscriber.subscribe('cache:invalidate');
}

/**
 * Publish cache invalidation event
 * @param pattern - Cache key pattern to invalidate
 */
export async function publishCacheInvalidation(pattern: string): Promise<void> {
  try {
    await redis.publish('cache:invalidate', JSON.stringify({ pattern }));
  } catch (error) {
    console.error('Failed to publish cache invalidation:', error);
  }
}
