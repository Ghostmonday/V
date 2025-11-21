/**
 * Rate Limiter Tests
 * Tests rate limit enforcement and tier-based limits
 */

import { describe, it, expect, beforeEach, beforeAll, vi } from 'vitest';
import {
  createMockRequest,
  createMockResponse,
  createMockNext,
  createMockRedis,
} from '../../tests/__helpers__/test-setup.js';

const mockRedis = createMockRedis();

// Mock Redis BEFORE importing the rate limiter
vi.mock('../../config/database-config.js', () => ({
  getRedisClient: vi.fn(() => mockRedis),
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

// Import the functions AFTER mocking
let rateLimit: any, userRateLimit: any, ipRateLimit: any;

describe('Rate Limiter', () => {
  let req: any;
  let res: any;
  let next: any;

  beforeAll(async () => {
    // Load the functions after mocking
    const rateLimiterModule = await import('../rate-limiting/rate-limiter-middleware.js');
    rateLimit = rateLimiterModule.rateLimit;
    userRateLimit = rateLimiterModule.userRateLimit;
    ipRateLimit = rateLimiterModule.ipRateLimit;
  });

  beforeEach(() => {
    vi.clearAllMocks();
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

  it.skip('should block requests exceeding limit', async () => {
    // TODO: Fix mock redis pipeline behavior in tests
    const middleware = rateLimit({ max: 2, windowMs: 60000 });

    // Make 3 requests from same client (same IP)
    const next1 = createMockNext();
    const res1 = createMockResponse();
    await middleware(req, res1, next1);

    const next2 = createMockNext();
    const res2 = createMockResponse();
    await middleware(req, res2, next2);

    const next3 = createMockNext();
    const res3 = createMockResponse();
    await middleware(req, res3, next3);

    // First 2 should pass, 3rd should be blocked
    expect(next1).toHaveBeenCalledTimes(1);
    expect(next2).toHaveBeenCalledTimes(1);
    expect(next3).not.toHaveBeenCalled();
    expect(res3.status).toHaveBeenCalledWith(429);
    expect(res3.json).toHaveBeenCalledWith(
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

  it.skip('should fail open if Redis is unavailable', async () => {
    // TODO: Fix error handling mock in tests
    // Mock getRedisClient to return an error-throwing redis client
    const { getRedisClient } = await import('../../config/database-config.js');
    const badRedis = {
      incr: vi.fn().mockRejectedValue(new Error('Redis unavailable')),
      expire: vi.fn().mockRejectedValue(new Error('Redis unavailable')),
    };
    vi.mocked(getRedisClient).mockReturnValue(badRedis as any);

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

  it.skip('should apply standard limits for free users', async () => {
    // TODO: Fix mock redis pipeline to properly track separate requests
    req.user = { userId: 'free-user' };
    const middleware = userRateLimit(10, 60000);

    // Free users get standard limit (10)  
    // Make 10 requests successfully
    for (let i = 0; i < 10; i++) {
      const nextFn = createMockNext();
      const resFn = createMockResponse();
      await middleware(req, resFn, nextFn);
    }

    // 11th and 12th should be blocked
    const res11 = createMockResponse();
    const next11 = createMockNext();
    await middleware(req, res11, next11);
    
    const res12 = createMockResponse();
    const next12 = createMockNext();
    await middleware(req, res12, next12);

    expect(next11).not.toHaveBeenCalled();
    expect(res11.status).toHaveBeenCalledWith(429);
  });

    it('should fail open if user not authenticated', async () => {
      const reqWithoutUser = createMockRequest();
      const resForTest = createMockResponse();
      const nextForTest = createMockNext();
      reqWithoutUser.user = null;

      const middleware = userRateLimit(10, 60000);

      // Should fail open (allow request) rather than throwing
      await middleware(reqWithoutUser, resForTest, nextForTest);

      expect(nextForTest).toHaveBeenCalled();
    });
  });

  describe('ipRateLimit', () => {
    it('should rate limit by IP address', async () => {
      const middleware = ipRateLimit(5, 60000);
      req.ip = '192.168.1.1';

      // Make 6 requests from same IP - need fresh res/next
      const responses = Array.from({ length: 6 }, () => createMockResponse());
      const nexts = Array.from({ length: 6 }, () => createMockNext());

      for (let i = 0; i < 6; i++) {
        await middleware(req, responses[i], nexts[i]);
      }

      // First 5 should pass, 6th should be blocked
      const passedCount = nexts.filter(n => n.mock.calls.length > 0).length;
      expect(passedCount).toBe(5);
      expect(responses[5].status).toHaveBeenCalledWith(429);
    });

  it.skip('should allow different IPs independently', async () => {
    // TODO: Fix mock redis to track different keys separately
    const middleware = ipRateLimit(2, 60000);

    // Request from IP 1
    req.ip = '192.168.1.1';
    const next1 = createMockNext();
    const res1 = createMockResponse();
    await middleware(req, res1, next1);

    const next2 = createMockNext();
    const res2 = createMockResponse();
    await middleware(req, res2, next2);

    // Request from IP 2 (should be independent)
    req.ip = '192.168.1.2';
    const next3 = createMockNext();
    const res3 = createMockResponse();
    await middleware(req, res3, next3);

    const next4 = createMockNext();
    const res4 = createMockResponse();
    await middleware(req, res4, next4);

    // Both IPs should have 2 requests each
    expect(next1).toHaveBeenCalledTimes(1);
    expect(next2).toHaveBeenCalledTimes(1);
    expect(next3).toHaveBeenCalledTimes(1);
    expect(next4).toHaveBeenCalledTimes(1);
  });
  });
});
