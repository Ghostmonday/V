// Type declarations for third-party packages
// This file provides type definitions until dependencies are properly installed

declare module 'ws' {
  export class WebSocket {
    constructor(address: string | URL, protocols?: string | string[]);
    send(data: string | Buffer | ArrayBuffer | Buffer[]): void;
    close(code?: number, reason?: string): void;
    ping(data?: Buffer): void;
    pong(data?: Buffer): void;
    on(event: 'message', listener: (data: Buffer) => void): this;
    on(event: 'close', listener: (code: number, reason: Buffer) => void): this;
    on(event: 'error', listener: (error: Error) => void): this;
    on(event: 'open', listener: () => void): this;
    on(event: 'ping', listener: (data: Buffer) => void): this;
    on(event: 'pong', listener: (data: Buffer) => void): this;
    readyState: number;
    static readonly OPEN: number;
    static readonly CLOSED: number;
    static readonly CLOSING: number;
    static readonly CONNECTING: number;
  }

  export class WebSocketServer {
    constructor(options?: {
      port?: number;
      host?: string;
      path?: string;
      noServer?: boolean;
    });
    on(event: 'connection', listener: (ws: WebSocket, req: any) => void): this;
    on(event: 'error', listener: (error: Error) => void): this;
    emit(event: string, ...args: any[]): boolean;
    close(callback?: () => void): void;
  }
}

declare module 'zod' {
  export interface ZodString {
    uuid(): ZodString;
    min(length: number): ZodString;
    max(length: number): ZodString;
    optional(): ZodString;
  }

  export interface ZodNumber {
    optional(): ZodNumber;
  }

  export interface ZodBoolean {
    optional(): ZodBoolean;
  }

  export interface ZodObject<T extends Record<string, any>> {
    parse(data: unknown): T;
    safeParse(data: unknown): { success: boolean; data?: T; error?: any };
    shape: T;
    extend<U extends Record<string, any>>(shape: U): ZodObject<T & U>;
    optional(): ZodObject<T>;
  }

  export namespace z {
    export function string(): ZodString;
    export function number(): ZodNumber;
    export function boolean(): ZodBoolean;
    export function object<T extends Record<string, any>>(shape: T): ZodObject<T>;
    export function union<T extends any[]>(types: T): any;
    
    export namespace infer {
      type Type<T> = T extends ZodObject<infer U> ? U : any;
    }
  }

  export const z: typeof z;
}

declare module 'bcrypt' {
  export function hash(data: string | Buffer, saltOrRounds: string | number): Promise<string>;
  export function compare(data: string | Buffer, encrypted: string): Promise<boolean>;
  export function genSalt(rounds?: number): Promise<string>;
}

declare module 'argon2' {
  export function hash(password: string | Buffer, options?: any): Promise<string>;
  export function verify(hash: string, password: string | Buffer): Promise<boolean>;
}

declare module 'protobufjs' {
  export interface Root {
    lookupType(name: string): Type;
    load(path: string): Promise<Root>;
  }

  export interface Type {
    encode(message: any): Writer;
    decode(reader: Reader | Uint8Array): any;
  }

  export interface Writer {
    finish(): Uint8Array;
  }

  export interface Reader {
    // Reader interface
  }

  function load(path: string): Promise<Root>;
  
  interface ProtobufDefault {
    Root: {
      new (): Root;
    };
    load(path: string): Promise<Root>;
  }
  
  const protobuf: ProtobufDefault;
  export default protobuf;
}

// Global type augmentation for protobuf namespace access
declare global {
  namespace protobuf {
    type Root = import('protobufjs').Root;
  }
}

declare module 'prom-client' {
  export interface Counter {
    inc(labels?: Record<string, string>): void;
  }

  export interface Gauge {
    set(value: number, labels?: Record<string, string>): void;
    inc(labels?: Record<string, string>): void;
    dec(labels?: Record<string, string>): void;
  }

  export interface Histogram {
    observe(value: number, labels?: Record<string, string>): void;
  }

  export class Registry {
    // Registry methods
  }

  export class Counter {
    constructor(options: { name: string; help: string; labelNames?: string[] });
    inc(labels?: Record<string, string>): void;
  }

  export class Gauge {
    constructor(options: { name: string; help: string; labelNames?: string[] });
    set(value: number, labels?: Record<string, string>): void;
    set(labels: Record<string, string>): void;
    inc(labels?: Record<string, string>): void;
    dec(labels?: Record<string, string>): void;
  }

  export class Histogram {
    constructor(options: { name: string; help: string; labelNames?: string[]; buckets?: number[] });
    observe(labels: Record<string, string>, value: number): void;
  }

  const client: {
    Counter: new (options: { name: string; help: string; labelNames?: string[] }) => Counter;
    Gauge: new (options: { name: string; help: string; labelNames?: string[] }) => Gauge;
    Histogram: new (options: { name: string; help: string; labelNames?: string[]; buckets?: number[] }) => Histogram;
    Registry: typeof Registry;
  };
  export default client;
}

