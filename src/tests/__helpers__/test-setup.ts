/**
 * Test Setup & Helpers
 * Shared test utilities, mocks, and fixtures
 */

import { vi } from 'vitest';
import type { RedisClientType } from 'redis';

/**
 * Mock Redis client for testing
 */
export function createMockRedis(): Partial<RedisClientType> {
  const store = new Map<string, string>();
  const sortedSets = new Map<string, Map<string, number>>();

  return {
    get: vi.fn(async (key: string) => {
      return store.get(key) || null;
    }),
    set: vi.fn(async (key: string, value: string) => {
      store.set(key, value);
      return 'OK';
    }),
    setex: vi.fn(async (key: string, seconds: number, value: string) => {
      store.set(key, value);
      // Simulate TTL by storing expiration time
      setTimeout(() => store.delete(key), seconds * 1000);
      return 'OK';
    }),
    del: vi.fn(async (key: string) => {
      const deleted = store.delete(key);
      return deleted ? 1 : 0;
    }),
    exists: vi.fn(async (key: string) => {
      return store.has(key) ? 1 : 0;
    }),
    incr: vi.fn(async (key: string) => {
      const current = parseInt(store.get(key) || '0', 10);
      const next = current + 1;
      store.set(key, next.toString());
      return next;
    }),
    decr: vi.fn(async (key: string) => {
      const current = parseInt(store.get(key) || '0', 10);
      const next = Math.max(0, current - 1);
      store.set(key, next.toString());
      return next;
    }),
    expire: vi.fn(async (key: string, seconds: number) => {
      if (store.has(key)) {
        setTimeout(() => store.delete(key), seconds * 1000);
        return 1;
      }
      return 0;
    }),
    // Sorted set operations for rate limiting
    zadd: vi.fn(async (key: string, score: number, member: string) => {
      if (!sortedSets.has(key)) {
        sortedSets.set(key, new Map());
      }
      sortedSets.get(key)!.set(member, score);
      return 1;
    }),
    zremrangebyscore: vi.fn(async (key: string, min: number, max: number) => {
      const set = sortedSets.get(key);
      if (!set) return 0;
      let removed = 0;
      for (const [member, score] of set.entries()) {
        if (score >= min && score <= max) {
          set.delete(member);
          removed++;
        }
      }
      return removed;
    }),
    zcard: vi.fn(async (key: string) => {
      return sortedSets.get(key)?.size || 0;
    }),
    pipeline: vi.fn(() => {
      // Store pipeline commands to execute them in sequence
      const commands: Array<{ method: string; args: any[] }> = [];

      const pipelineObj = {
        zremrangebyscore: vi.fn((...args: any[]) => {
          commands.push({ method: 'zremrangebyscore', args });
          return pipelineObj;
        }),
        zcard: vi.fn((...args: any[]) => {
          commands.push({ method: 'zcard', args });
          return pipelineObj;
        }),
        zadd: vi.fn((...args: any[]) => {
          commands.push({ method: 'zadd', args });
          return pipelineObj;
        }),
        expire: vi.fn((...args: any[]) => {
          commands.push({ method: 'expire', args });
          return pipelineObj;
        }),
        exec: vi.fn(async () => {
          // Execute commands in order and collect results
          const results: Array<[Error | null, any]> = [];

          for (const cmd of commands) {
            const [key, ...rest] = cmd.args;

            if (cmd.method === 'zremrangebyscore') {
              const [min, max] = rest;
              const set = sortedSets.get(key);
              let removed = 0;
              if (set) {
                for (const [member, score] of set.entries()) {
                  if (score >= min && score <= max) {
                    set.delete(member);
                    removed++;
                  }
                }
              }
              results.push([null, removed]);
            } else if (cmd.method === 'zcard') {
              const size = sortedSets.get(key)?.size || 0;
              results.push([null, size]);
            } else if (cmd.method === 'zadd') {
              const [score, member] = rest;
              if (!sortedSets.has(key)) {
                sortedSets.set(key, new Map());
              }
              sortedSets.get(key)!.set(member, score);
              results.push([null, 1]);
            } else if (cmd.method === 'expire') {
              results.push([null, 1]);
            }
          }

          return results;
        }),
      };

      return pipelineObj;
    }),
    hget: vi.fn(async (key: string, field: string) => {
      // Mock hash get for user tier caching
      return null;
    }),
    hset: vi.fn(async (key: string, field: string, value: string) => {
      return 1;
    }),
  } as any;
}

/**
 * Mock Supabase client for testing
 */
export function createMockSupabase() {
  const mockData: Record<string, any[]> = {};

  return {
    from: vi.fn((table: string) => ({
      select: vi.fn().mockReturnThis(),
      insert: vi.fn().mockReturnThis(),
      update: vi.fn().mockReturnThis(),
      delete: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      single: vi.fn(async () => {
        const tableData = mockData[table] || [];
        return { data: tableData[0] || null, error: null };
      }),
      then: vi.fn(async (callback: any) => {
        const tableData = mockData[table] || [];
        return callback({ data: tableData, error: null });
      }),
    })),
    auth: {
      signInWithPassword: vi.fn(
        async ({ email, password }: { email: string; password: string }) => {
          if (email === 'test@example.com' && password === 'password123') {
            return {
              data: {
                user: {
                  id: 'user-123',
                  email,
                },
              },
              error: null,
            };
          }
          return {
            data: { user: null },
            error: { message: 'Invalid credentials' },
          };
        }
      ),
    },
    // Helper to set mock data
    _setMockData: (table: string, data: any[]) => {
      mockData[table] = data;
    },
  };
}

/**
 * Test fixtures
 */
export const testFixtures = {
  user: {
    id: 'user-123',
    email: 'test@example.com',
    tier: 'free' as const,
    handle: 'testuser',
  },
  room: {
    id: 'room-123',
    name: 'Test Room',
    is_public: true,
  },
  message: {
    id: 'msg-123',
    room_id: 'room-123',
    sender_id: 'user-123',
    content: 'Hello, world!',
    message_type: 'text',
  },
  refreshToken: 'test-refresh-token-123',
  accessToken: 'test-access-token-123',
};

/**
 * Wait for async operations
 */
export function wait(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Create mock Express request
 */
export function createMockRequest(overrides: any = {}) {
  return {
    ip: '127.0.0.1',
    headers: {
      'user-agent': 'test-agent',
      ...overrides.headers,
    },
    body: {},
    cookies: {},
    user: null,
    ...overrides,
  };
}

/**
 * Create mock Express response
 */
export function createMockResponse() {
  const res: any = {
    status: vi.fn().mockReturnThis(),
    json: vi.fn().mockReturnThis(),
    send: vi.fn().mockReturnThis(),
    setHeader: vi.fn().mockReturnThis(),
    cookie: vi.fn().mockReturnThis(),
    clearCookie: vi.fn().mockReturnThis(),
  };
  return res;
}

/**
 * Create mock Express next function
 */
export function createMockNext() {
  return vi.fn();
}
