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
  SubscriptionTier: {
    FREE: 'free',
    PRO: 'pro',
    TEAM: 'team',
  },
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
    // Clear mock Redis state (sortedSets Map) to prevent test pollution
    const redisMock = mockRedis as any;
    if (redisMock._sortedSets) {
      redisMock._sortedSets.clear();
    }
    // Also clear the store Map if it exists
    if (redisMock._store) {
      redisMock._store.clear();
    }
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

  it('should fail open if Redis is unavailable', async () => {
    // Mock getRedisClient to return an error-throwing redis client
    const { getRedisClient } = await import('../../config/database-config.js');
    const badRedis = {
      pipeline: vi.fn(() => ({
        zremrangebyscore: vi.fn().mockReturnThis(),
        zcard: vi.fn().mockReturnThis(),
        zadd: vi.fn().mockReturnThis(),
        expire: vi.fn().mockReturnThis(),
        exec: vi.fn().mockRejectedValue(new Error('Redis unavailable')),
      })),
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

  it('should apply standard limits for free users', async () => {
    req.user = { userId: 'free-user' };
    const middleware = userRateLimit(10, 60000);

    // Free users get standard limit (10)  
    // Make 10 requests successfully
    const nexts: any[] = [];
    const ress: any[] = [];
    for (let i = 0; i < 10; i++) {
      const nextFn = createMockNext();
      const resFn = createMockResponse();
      nexts.push(nextFn);
      ress.push(resFn);
      await middleware(req, resFn, nextFn);
    }

    // All 10 should pass
    for (let i = 0; i < 10; i++) {
      expect(nexts[i]).toHaveBeenCalledTimes(1);
      expect(ress[i].status).not.toHaveBeenCalled();
    }

    // 11th should be blocked
    const res11 = createMockResponse();
    const next11 = createMockNext();
    await middleware(req, res11, next11);

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

  it('should allow different IPs independently', async () => {
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

    // Both IPs should have 2 requests each (limit is 2 per IP)
    expect(next1).toHaveBeenCalledTimes(1);
    expect(next2).toHaveBeenCalledTimes(1);
    expect(next3).toHaveBeenCalledTimes(1);
    expect(next4).toHaveBeenCalledTimes(1);
    // None should be blocked
    expect(res1.status).not.toHaveBeenCalled();
    expect(res2.status).not.toHaveBeenCalled();
    expect(res3.status).not.toHaveBeenCalled();
    expect(res4.status).not.toHaveBeenCalled();
  });
  });
});
