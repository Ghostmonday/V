// Type declarations for vitest and redis
// This file provides type definitions until dependencies are properly installed

declare module 'vitest' {
  export interface Mock {
    (...args: any[]): any;
    mockReturnValue(value: any): this;
    mockReturnValueOnce(value: any): this;
    mockResolvedValue(value: any): this;
    mockResolvedValueOnce(value: any): this;
    mockRejectedValue(value: any): this;
    mockRejectedValueOnce(value: any): this;
    mockImplementation(fn: (...args: any[]) => any): this;
    mockImplementationOnce(fn: (...args: any[]) => any): this;
    mockReturnThis(): this;
    mock: {
      calls: any[][];
      results: any[];
      instances: any[];
    };
  }

  export interface Vi {
    fn: (implementation?: (...args: any[]) => any) => Mock;
    mock: (module: string, factory?: () => any) => void;
    spyOn: (obj: any, method: string) => Mock;
    clearAllMocks: () => void;
    mocked: <T>(value: T) => T & Mock;
  }

  export interface ExpectMatchers {
    toBe(expected: any): void;
    toEqual(expected: any): void;
    toHaveBeenCalled(): void;
    toHaveBeenCalledTimes(times: number): void;
    toHaveBeenCalledWith(...args: any[]): void;
    toBeDefined(): void;
    toContain(item: any): void;
    toBeLessThanOrEqual(value: number): void;
    toBeGreaterThanOrEqual(value: number): void;
    not: ExpectMatchers;
    rejects: {
      toThrow(message?: string | RegExp): Promise<void>;
    };
  }

  export interface ExpectStatic {
    (actual: any): ExpectMatchers;
    objectContaining(obj: Record<string, any>): any;
    any(constructor: any): any;
    stringContaining(str: string): any;
    anything(): any;
  }

  export const expect: ExpectStatic;
  export const vi: Vi;
  export function describe(name: string, fn: () => void): void;
  export function it(name: string, fn: (...args: any[]) => void | Promise<void>): void;
  export function test(name: string, fn: (...args: any[]) => void | Promise<void>): void;
  export function beforeEach(fn: () => void | Promise<void>): void;
  export function afterEach(fn: () => void | Promise<void>): void;
  export function beforeAll(fn: () => void | Promise<void>): void;
  export function afterAll(fn: () => void | Promise<void>): void;
}

declare module 'vitest/config' {
  export function defineConfig(config: any): any;
}

declare module 'redis' {
  export interface RedisClientType {
    get(key: string): Promise<string | null>;
    set(key: string, value: string): Promise<string>;
    setex(key: string, seconds: number, value: string): Promise<string>;
    del(key: string): Promise<number>;
    exists(key: string): Promise<number>;
    incr(key: string): Promise<number>;
    decr(key: string): Promise<number>;
    expire(key: string, seconds: number): Promise<number>;
    zadd(key: string, score: number, member: string): Promise<number>;
    zremrangebyscore(key: string, min: number, max: number): Promise<number>;
    zcard(key: string): Promise<number>;
    hget(key: string, field: string): Promise<string | null>;
    hset(key: string, field: string, value: string): Promise<number>;
    pipeline(): {
      zremrangebyscore(key: string, min: number, max: number): any;
      zcard(key: string): any;
      zadd(key: string, score: number, member: string): any;
      expire(key: string, seconds: number): any;
      exec(): Promise<Array<[Error | null, any]>>;
    };
  }
}

