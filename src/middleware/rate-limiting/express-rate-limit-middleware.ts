/**
 * Express Rate Limit Middleware
 * Uses express-rate-limit with Redis store backend
 * Provides tiered rate limits based on user subscription tier
 */

import rateLimit from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { getRedisClient } from '../../config/database-config.js';
import { getUserSubscription, SubscriptionTier } from '../../services/subscription-service.js';
import { AuthenticatedRequest } from '../../types/auth.types.js';
import { Request, Response } from 'express';

const redis = getRedisClient();

// Create Redis store for rate limiting
const redisStore = new RedisStore({
  client: redis,
  prefix: 'rl:', // Rate limit prefix
});

/**
 * Default rate limit configuration
 * 100 requests per 15 minutes per IP
 */
export const defaultRateLimit = rateLimit({
  store: redisStore,
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  message: 'Too many requests from this IP, please try again later.',
  handler: (req: Request, res: Response) => {
    res.status(429).json({
      error: 'Rate limit exceeded',
      message: 'Too many requests, please try again later.',
      retryAfter: Math.ceil(15 * 60), // Seconds
    });
  },
});

/**
 * Strict rate limit for sensitive endpoints
 * 10 requests per 15 minutes per IP
 */
export const strictRateLimit = rateLimit({
  store: redisStore,
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Too many requests, please slow down.',
  handler: (req: Request, res: Response) => {
    res.status(429).json({
      error: 'Rate limit exceeded',
      message: 'Too many requests to this sensitive endpoint, please try again later.',
      retryAfter: Math.ceil(15 * 60),
    });
  },
});

/**
 * Tiered rate limit based on user subscription
 * Free: 100 req/15min, Pro: 500 req/15min, Enterprise: 2000 req/15min
 */
export const tieredRateLimit = rateLimit({
  store: redisStore,
  windowMs: 15 * 60 * 1000,
  max: async (req: AuthenticatedRequest) => {
    // Default to free tier limit
    if (!req.user?.userId) {
      return 100;
    }

    try {
      const tier = await getUserSubscription(req.user.userId);

      switch (tier) {
        case SubscriptionTier.FREE:
          return 100;
        case SubscriptionTier.PRO:
          return 500;
        case SubscriptionTier.ENTERPRISE:
          return 2000;
        default:
          return 100;
      }
    } catch (error) {
      // On error, default to free tier
      return 100;
    }
  },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req: AuthenticatedRequest) => {
    // Use user ID if authenticated, otherwise use IP
    return req.user?.userId || req.ip || 'unknown';
  },
  message: 'Rate limit exceeded for your subscription tier.',
  handler: (req: Request, res: Response) => {
    res.status(429).json({
      error: 'Rate limit exceeded',
      message: 'You have exceeded the rate limit for your subscription tier.',
      retryAfter: Math.ceil(15 * 60),
    });
  },
});

/**
 * Per-user rate limit (requires authentication)
 * 200 requests per 15 minutes per user
 */
export const userRateLimit = rateLimit({
  store: redisStore,
  windowMs: 15 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req: AuthenticatedRequest) => {
    if (!req.user?.userId) {
      throw new Error('User rate limit requires authentication');
    }
    return `user:${req.user.userId}`;
  },
  message: 'Too many requests from this user account.',
  handler: (req: Request, res: Response) => {
    res.status(429).json({
      error: 'Rate limit exceeded',
      message: 'Too many requests from this account, please try again later.',
      retryAfter: Math.ceil(15 * 60),
    });
  },
  skip: (req: AuthenticatedRequest) => {
    // Skip rate limiting if user is not authenticated
    return !req.user?.userId;
  },
});

/**
 * API key rate limit
 * For endpoints that use API keys instead of user authentication
 * 1000 requests per hour per API key
 */
export const apiKeyRateLimit = rateLimit({
  store: redisStore,
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 1000,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req: Request) => {
    // Extract API key from header
    const apiKey = req.headers['x-api-key'] || req.headers['authorization'];
    return apiKey ? `apikey:${apiKey}` : req.ip || 'unknown';
  },
  message: 'API key rate limit exceeded.',
  handler: (req: Request, res: Response) => {
    res.status(429).json({
      error: 'Rate limit exceeded',
      message: 'API key rate limit exceeded, please try again later.',
      retryAfter: Math.ceil(60 * 60),
    });
  },
});
