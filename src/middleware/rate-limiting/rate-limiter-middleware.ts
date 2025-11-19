/**
 * Rate Limiter Middleware
 * Implements token bucket algorithm for API rate limiting and DDoS protection
 */

import { Response, NextFunction } from 'express';
import { getRedisClient } from '../../config/database-config.js';
import { logWarning } from '../../shared/logger-shared.js';
import { AuthenticatedRequest } from '../../types/auth.types.js';
import { getUserSubscription, SubscriptionTier } from '../../services/subscription-service.js';
import * as Sentry from '@sentry/node';

const redis = getRedisClient();

export interface RateLimitOptions {
  windowMs: number; // Time window in milliseconds
  max: number; // Maximum requests per window
  keyGenerator?: (req: AuthenticatedRequest) => string; // Custom key generator
  skipSuccessfulRequests?: boolean; // Don't count successful requests
  skipFailedRequests?: boolean; // Don't count failed requests
  message?: string; // Custom error message
}

const defaultOptions: RateLimitOptions = {
  windowMs: 60000, // 1 minute
  max: 100, // 100 requests per minute
  keyGenerator: (req: AuthenticatedRequest) => {
    // Use IP address or user ID if authenticated
    return req.user?.userId || req.ip || 'unknown';
  },
  message: 'Too many requests, please try again later.',
};

/**
 * Rate limiter middleware factory
 */
export function rateLimit(options: Partial<RateLimitOptions> = {}) {
  const opts = { ...defaultOptions, ...options };
  const windowMs = opts.windowMs;
  const max = opts.max;

  return async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    try {
      // Generate unique key for this client (IP or user ID)
      // Format: "rate_limit:{identifier}" - used as Redis sorted set key
      const key = `rate_limit:${opts.keyGenerator!(req)}`;
      const now = Date.now(); // Current timestamp in milliseconds

      // Use Redis pipeline for atomic operations (all succeed or all fail)
      // Sliding window log algorithm: track each request with timestamp
      const pipeline = redis.pipeline();

      // Step 1: Remove old entries outside the time window
      // zremrangebyscore removes entries with scores (timestamps) < (now - windowMs)
      // This keeps only requests within the current window
      pipeline.zremrangebyscore(key, 0, now - windowMs);

      // Step 2: Count remaining requests in the window
      // zcard returns count of entries in sorted set (requests in current window)
      pipeline.zcard(key);

      // Step 3: Add current request to the window
      // Score = timestamp (for sorting/expiration)
      // Value = unique identifier (timestamp + random to prevent collisions)
      pipeline.zadd(key, now, `${now}-${Math.random()}`);

      // Step 4: Set expiration on the key (cleanup if no requests for a while)
      // Expire after windowMs (convert to seconds for Redis EXPIRE command)
      pipeline.expire(key, Math.ceil(windowMs / 1000));

      // Execute all pipeline commands atomically
      const results = await pipeline.exec();

      // Add Sentry breadcrumb for monitoring
      if (!results) {
        Sentry.addBreadcrumb({
          message: 'Redis pipeline failed in rate limiter',
          level: 'warning',
          data: { key },
        });
      }

      // Extract count from pipeline results: results[1] is zcard result, [1] is the count value
      const count = (results?.[1]?.[1] as number) || 0;

      // Set standard rate limit headers (RFC 6585 compliant)
      res.setHeader('X-RateLimit-Limit', max.toString()); // Max requests allowed
      res.setHeader('X-RateLimit-Remaining', Math.max(0, max - count - 1).toString()); // Requests left (max - current - 1)
      res.setHeader('X-RateLimit-Reset', new Date(now + windowMs).toISOString()); // When window resets

      // Check if limit exceeded
      if (count >= max) {
        logWarning(`Rate limit exceeded for ${opts.keyGenerator!(req)}`);
        return res.status(429).json({
          // 429 = Too Many Requests
          error: 'Rate limit exceeded',
          message: opts.message,
          retryAfter: Math.ceil(windowMs / 1000), // Seconds until retry allowed
        });
      }

      // Request allowed - continue to next middleware/route handler
      next();
    } catch (error: unknown) {
      // If Redis fails, fail open (allow request) rather than fail closed (block all)
      // This prevents Redis outages from taking down the entire API
      // Log error for monitoring but don't block legitimate users
      const err = error instanceof Error ? error : new Error(String(error));
      logWarning('Rate limiter Redis error, allowing request', err);

      // Add Sentry breadcrumb for monitoring silent failures
      Sentry.addBreadcrumb({
        message: 'Rate limiter Redis error - failing open',
        level: 'warning',
        data: {
          error: err.message,
          key: opts.keyGenerator!(req),
        },
      });

      // Report to Sentry but don't block request
      Sentry.captureException(err, {
        tags: { component: 'rate-limiter', failOpen: 'true' },
      });

      next(); // Allow request to proceed
    }
  };
}

/**
 * Strict rate limiter for critical endpoints
 */
export function strictRateLimit(max: number, windowMs: number = 60000) {
  return rateLimit({
    max,
    windowMs,
    message: 'Rate limit exceeded. Please slow down.',
  });
}

/**
 * Per-user rate limiter (requires authentication)
 * Caches user subscription tier in Redis to avoid DB hits
 */
export function userRateLimit(max: number, windowMs: number = 60000) {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    try {
      const userId = req.user?.userId;
      if (!userId) {
        throw new Error('User rate limit requires authentication');
      }

      // Check Redis cache for user tier (1min TTL)
      const cacheKey = `user_rate:${userId}`;
      const cachedTier = await redis.hget('user_rate', userId);

      let tier: SubscriptionTier;
      if (cachedTier) {
        tier = cachedTier as SubscriptionTier;
      } else {
        // Cache miss - fetch from DB and cache
        tier = await getUserSubscription(userId);
        await redis.hset('user_rate', userId, tier);
        await redis.expire('user_rate', 60); // 1 minute TTL
      }

      // Map tier to max rate (free: max, pro/team: higher limits)
      const tierMax = tier === SubscriptionTier.FREE ? max : max * 2;

      // Use tier-specific rate limit
      return rateLimit({
        max: tierMax,
        windowMs,
        keyGenerator: () => `user:${userId}`,
      })(req, res, next);
    } catch (error: unknown) {
      const err = error instanceof Error ? error : new Error(String(error));
      logWarning('User rate limit error, allowing request', err);
      next(); // Fail open
    }
  };
}

/**
 * Per-IP rate limiter for DDoS protection
 */
export function ipRateLimit(max: number = 1000, windowMs: number = 60000) {
  return rateLimit({
    max,
    windowMs,
    keyGenerator: (req: AuthenticatedRequest) => {
      return `ip:${req.ip || req.socket.remoteAddress || 'unknown'}`;
    },
    message: 'Too many requests from this IP address.',
  });
}

/**
 * NEW: Simple default rate limiter middleware
 * - 60 requests per 60 seconds per IP
 * - Fails open if Redis is unavailable (logs error, allows request)
 * - Uses existing Redis client from config/database-config.js
 */
import { Request } from 'express';

const simpleRateLimiter = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const key = `rate:${req.ip || 'unknown'}`;
    const currentRaw = await redis.get(key);
    const current = currentRaw ? Number(currentRaw) : 0;

    if (current > 60) {
      return res.status(429).json({ error: 'Too Many Requests' });
    }

    await redis.multi().incr(key).expire(key, 60).exec();
  } catch (err) {
    // Fail open - log error but allow request through
    console.error('Rate limiter error', err);
    logWarning(
      'Rate limiter Redis error, allowing request',
      err instanceof Error ? err : new Error(String(err))
    );
  }

  next();
};

// Default export for simple rate limiting
export default simpleRateLimiter;
