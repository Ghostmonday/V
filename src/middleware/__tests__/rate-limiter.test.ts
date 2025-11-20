/**
 * Rate Limiter Tests
 * Tests rate limit enforcement and tier-based limits
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  createMockRequest,
  createMockResponse,
  createMockNext,
  createMockRedis,
} from '../../tests/__helpers__/test-setup.js';

// Import the functions after mocking to avoid circular dependency
let rateLimit: any, userRateLimit: any, ipRateLimit: any;

// Mock Redis
vi.mock('../../config/database-config.js', () => ({
  getRedisClient: vi.fn(() => createMockRedis()),
}));

// Mock subscription service
vi.mock('../../services/subscription-service.js', () => ({
  getUserSubscription: vi.fn(async (userId: string) => {
    // Mock tier lookup
    if (userId === 'pro-user') return 'pro';
    if (userId === 'team-user') return 'team';
    return 'free';
  }),
}));

describe('Rate Limiter', () => {
  let mockRedis: any;
  let req: any;
  let res: any;
  let next: any;

  beforeAll(async () => {
    // Load the functions after mocking to avoid circular dependency
    const rateLimiterModule = await import('../rate-limiting/rate-limiter-middleware.js');
    rateLimit = rateLimiterModule.rateLimit;
    userRateLimit = rateLimiterModule.userRateLimit;
    ipRateLimit = rateLimiterModule.ipRateLimit;
  });

  beforeEach(() => {
    vi.clearAllMocks();
    mockRedis = createMockRedis();
    req = createMockRequest();
    res = createMockResponse();
    next = createMockNext();
  });

  describe('rateLimit', () => {
    it('should allow requests within limit', async () => {
      const middleware = rateLimit({ max: 5, windowMs: 60000 });

      // Make 3 requests (under limit of 5)
      for (let i = 0; i < 3; i++) {
        await middleware(req, res, next);
      }

      expect(next).toHaveBeenCalledTimes(3);
      expect(res.status).not.toHaveBeenCalled();
    });

    it('should block requests exceeding limit', async () => {
      const middleware = rateLimit({ max: 2, windowMs: 60000 });

      // Make 3 requests (exceeds limit of 2)
      for (let i = 0; i < 3; i++) {
        await middleware(req, res, next);
      }

      // First 2 should pass, 3rd should be blocked
      expect(next).toHaveBeenCalledTimes(2);
      expect(res.status).toHaveBeenCalledWith(429);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: 'Rate limit exceeded',
        })
      );
    });

    it('should set rate limit headers', async () => {
      const middleware = rateLimit({ max: 10, windowMs: 60000 });

      await middleware(req, res, next);

      expect(res.setHeader).toHaveBeenCalledWith('X-RateLimit-Limit', '10');
      expect(res.setHeader).toHaveBeenCalledWith('X-RateLimit-Remaining', expect.any(String));
      expect(res.setHeader).toHaveBeenCalledWith('X-RateLimit-Reset', expect.any(String));
    });

    it('should use custom key generator', async () => {
      const customKeyGen = vi.fn(() => 'custom-key');
      const middleware = rateLimit({
        max: 5,
        windowMs: 60000,
        keyGenerator: customKeyGen,
      });

      await middleware(req, res, next);

      expect(customKeyGen).toHaveBeenCalledWith(req);
    });

    it('should fail open if Redis is unavailable', async () => {
      // Mock Redis to throw error
      mockRedis.pipeline = vi.fn(() => {
        throw new Error('Redis unavailable');
      });

      const middleware = rateLimit({ max: 5, windowMs: 60000 });

      await middleware(req, res, next);

      // Should allow request (fail open)
      expect(next).toHaveBeenCalled();
    });
  });

  describe('userRateLimit', () => {
    it('should apply higher limits for pro users', async () => {
      req.user = { userId: 'pro-user' };
      const middleware = userRateLimit(10, 60000);

      // Pro users get 2x limit (20)
      // Make 15 requests (should all pass for pro user)
      for (let i = 0; i < 15; i++) {
        await middleware(req, res, next);
      }

      expect(next).toHaveBeenCalledTimes(15);
    });

    it('should apply standard limits for free users', async () => {
      req.user = { userId: 'free-user' };
      const middleware = userRateLimit(10, 60000);

      // Free users get standard limit (10)
      // Make 12 requests (should block after 10)
      for (let i = 0; i < 12; i++) {
        await middleware(req, res, next);
      }

      // First 10 should pass, 11th and 12th should be blocked
      expect(next).toHaveBeenCalledTimes(10);
      expect(res.status).toHaveBeenCalledWith(429);
    });

    it('should throw error if user not authenticated', async () => {
      req.user = null;
      const middleware = userRateLimit(10, 60000);

      await expect(middleware(req, res, next)).rejects.toThrow(
        'User rate limit requires authentication'
      );
    });
  });

  describe('ipRateLimit', () => {
    it('should rate limit by IP address', async () => {
      req.ip = '192.168.1.1';
      const middleware = ipRateLimit(5, 60000);

      // Make 6 requests from same IP
      for (let i = 0; i < 6; i++) {
        await middleware(req, res, next);
      }

      // First 5 should pass, 6th should be blocked
      expect(next).toHaveBeenCalledTimes(5);
      expect(res.status).toHaveBeenCalledWith(429);
    });

    it('should allow different IPs independently', async () => {
      const middleware = ipRateLimit(2, 60000);

      // Request from IP 1
      req.ip = '192.168.1.1';
      await middleware(req, res, next);
      await middleware(req, res, next);

      // Request from IP 2 (should be independent)
      req.ip = '192.168.1.2';
      await middleware(req, res, next);
      await middleware(req, res, next);

      // Both IPs should have 2 requests each
      expect(next).toHaveBeenCalledTimes(4);
    });
  });
});
