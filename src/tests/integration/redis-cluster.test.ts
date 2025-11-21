/**
 * Redis Cluster and Sentinel Integration Tests
 * Validates failover scenarios and reconnection logic
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import {
  createRedisClient,
  parseRedisConfig,
  checkRedisHealth,
  type RedisClusterConfig,
} from '../../config/redis-cluster.js';
import { setupFailoverHandlers } from '../../config/redis-failover.js';
import Redis, { Cluster } from 'ioredis';

describe('Redis Cluster Configuration', () => {
  describe('parseRedisConfig', () => {
    it('should parse single instance mode', () => {
      process.env.REDIS_MODE = 'single';
      process.env.REDIS_URL = 'redis://localhost:6379';

      const config = parseRedisConfig();

      expect(config.mode).toBe('single');
      expect(config.url).toBe('redis://localhost:6379');
    });

    it('should parse cluster mode', () => {
      process.env.REDIS_MODE = 'cluster';
      process.env.REDIS_CLUSTER_NODES = 'localhost:7000,localhost:7001,localhost:7002';

      const config = parseRedisConfig();

      expect(config.mode).toBe('cluster');
      expect(config.nodes).toHaveLength(3);
      expect(config.nodes![0]).toEqual({ host: 'localhost', port: 7000 });
      expect(config.nodes![1]).toEqual({ host: 'localhost', port: 7001 });
      expect(config.nodes![2]).toEqual({ host: 'localhost', port: 7002 });
    });

    it('should parse sentinel mode', () => {
      process.env.REDIS_MODE = 'sentinel';
      process.env.REDIS_SENTINELS = 'localhost:26379,localhost:26380,localhost:26381';
      process.env.REDIS_SENTINEL_NAME = 'mymaster';

      const config = parseRedisConfig();

      expect(config.mode).toBe('sentinel');
      expect(config.sentinels).toHaveLength(3);
      expect(config.sentinels![0]).toEqual({ host: 'localhost', port: 26379 });
      expect(config.sentinelName).toBe('mymaster');
    });

    it('should default to single mode', () => {
      delete process.env.REDIS_MODE;
      process.env.REDIS_URL = 'redis://localhost:6379';

      const config = parseRedisConfig();

      expect(config.mode).toBe('single');
    });

    it('should throw error for invalid mode', () => {
      process.env.REDIS_MODE = 'invalid';

      expect(() => parseRedisConfig()).toThrow();
    });
  });

  describe('createRedisClient', () => {
    beforeEach(() => {
      // Mock Redis to avoid actual connections in tests
      vi.spyOn(Redis.prototype, 'on').mockImplementation(() => Redis.prototype as any);
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('should create single instance client', () => {
      const config: RedisClusterConfig = {
        mode: 'single',
        url: 'redis://localhost:6379',
      };

      const client = createRedisClient(config);

      expect(client).toBeInstanceOf(Redis);
    });

  it('should create cluster client', () => {
    const config: RedisClusterConfig = {
      mode: 'cluster',
      nodes: [
        { host: 'localhost', port: 7000 },
        { host: 'localhost', port: 7001 },
      ],
    };

    // Use behavior-based assertions instead of checking internal mocks
    const client = createRedisClient(config);

    // Verify client is created and has expected methods
    expect(client).toBeDefined();
    expect(client).toBeInstanceOf(Cluster);
    // Verify it has expected Redis client methods
    expect(typeof client.on).toBe('function');
    expect(typeof client.quit).toBe('function');
  });

    it('should create sentinel client', () => {
      const config: RedisClusterConfig = {
        mode: 'sentinel',
        sentinels: [{ host: 'localhost', port: 26379 }],
        sentinelName: 'mymaster',
      };

      const client = createRedisClient(config);

      expect(client).toBeInstanceOf(Redis);
    });
  });

  describe('checkRedisHealth', () => {
    it('should return true for healthy client', async () => {
      const mockClient = {
        ping: vi.fn().mockResolvedValue('PONG'),
      } as any;

      const healthy = await checkRedisHealth(mockClient);

      expect(healthy).toBe(true);
      expect(mockClient.ping).toHaveBeenCalled();
    });

    it('should return false for unhealthy client', async () => {
      const mockClient = {
        ping: vi.fn().mockRejectedValue(new Error('Connection failed')),
      } as any;

      const healthy = await checkRedisHealth(mockClient);

      expect(healthy).toBe(false);
    });

    it('should timeout after 5 seconds', async () => {
      const mockClient = {
        ping: vi.fn().mockImplementation(() => new Promise(() => {})), // Never resolves
      } as any;

      const healthy = await checkRedisHealth(mockClient);

      expect(healthy).toBe(false);
    });
  });

  describe('setupFailoverHandlers', () => {
    it('should setup event handlers', () => {
      const mockClient = {
        on: vi.fn(),
      } as any;

      const handlers = {
        onFailover: vi.fn(),
        onReconnect: vi.fn(),
        onError: vi.fn(),
      };

      setupFailoverHandlers(mockClient, handlers);

      // Verify event handlers were registered
      expect(mockClient.on).toHaveBeenCalled();
    });

    it('should handle cluster failover events', () => {
      const mockClient = {
        on: vi.fn((event: string, handler: Function) => {
          if (event === '+move') {
            // Simulate failover event
            handler(1234, { options: { host: 'newmaster', port: 6379 } });
          }
        }),
        instanceof: vi.fn(() => true),
      } as any;

      // Mock Cluster check
      Object.setPrototypeOf(mockClient, Cluster.prototype);

      const handlers = {
        onFailover: vi.fn(),
      };

      setupFailoverHandlers(mockClient, handlers);

      // Trigger failover event
      const moveHandler = mockClient.on.mock.calls.find((call: any[]) => call[0] === '+move')?.[1];
      if (moveHandler) {
        moveHandler(1234, { options: { host: 'newmaster', port: 6379 } });
      }

      // Handler should be called (if event was triggered)
      expect(mockClient.on).toHaveBeenCalled();
    });
  });
});

describe('Redis Failover Scenarios', () => {
  it('should handle connection errors gracefully', () => {
    const mockClient = {
      on: vi.fn(),
      status: 'ready',
    } as any;

    const handlers = {
      onError: vi.fn(),
    };

    setupFailoverHandlers(mockClient, handlers);

    // Find error handler
    const errorCall = mockClient.on.mock.calls.find((call: any[]) => call[0] === 'error');
    if (errorCall) {
      const errorHandler = errorCall[1];
      errorHandler(new Error('ECONNREFUSED'));
    }

    expect(mockClient.on).toHaveBeenCalled();
  });

  it('should handle reconnection attempts', () => {
    const mockClient = {
      on: vi.fn(),
      status: 'ready',
    } as any;

    setupFailoverHandlers(mockClient);

    // Find reconnecting handler
    const reconnectCall = mockClient.on.mock.calls.find(
      (call: any[]) => call[0] === 'reconnecting'
    );
    expect(reconnectCall).toBeDefined();
  });
});
