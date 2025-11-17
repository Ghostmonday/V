/// <reference lib="es2020" />
// Type declarations for Node.js built-in modules
// This file provides type definitions until @types/node is properly installed

declare module 'node:fs' {
  export * from 'fs';
}

declare module 'fs' {
  export function readFileSync(path: string | Buffer, encoding?: string): string | Buffer;
  export function readFileSync(path: string | Buffer, options?: { encoding?: string; flag?: string }): string | Buffer;
  export function writeFileSync(file: string | Buffer, data: string | Buffer, options?: { encoding?: string; mode?: number; flag?: string }): void;
  export function existsSync(path: string | Buffer): boolean;
  export function readdirSync(path: string | Buffer, options?: { encoding?: string; withFileTypes?: boolean }): string[];
  export function statSync(path: string | Buffer): {
    isFile(): boolean;
    isDirectory(): boolean;
    size: number;
    mtime: Date;
  };
}

declare module 'path' {
  export function join(...paths: string[]): string;
  export function dirname(path: string): string;
  export function basename(path: string, ext?: string): string;
  export function extname(path: string): string;
  export function resolve(...paths: string[]): string;
  export const sep: string;
  export const delimiter: string;
}

declare module 'node:url' {
  export * from 'url';
}

declare module 'url' {
  export function fileURLToPath(url: string | URL): string;
  export function pathToFileURL(path: string): URL;
}

declare module 'node:path' {
  export * from 'path';
}

declare module 'crypto' {
  export function createHash(algorithm: string): Hash;
  export function randomBytes(size: number): Buffer;
  export function randomUUID(): string;
  export function pbkdf2Sync(password: string | Buffer, salt: string | Buffer, iterations: number, keylen: number, digest: string): Buffer;
  export function createHmac(algorithm: string, key: string | Buffer): Hmac;
  export function createECDH(curve: string): ECDH;
  
  export interface Hash {
    update(data: string | Buffer): this;
    digest(encoding?: string): string | Buffer;
  }
  
  export interface Hmac {
    update(data: string | Buffer): this;
    digest(encoding?: string): string | Buffer;
  }
  
  export interface ECDH {
    generateKeys(encoding?: string, format?: string): string | Buffer;
    computeSecret(otherPublicKey: string | Buffer, inputEncoding?: string, outputEncoding?: string): string | Buffer;
    getPublicKey(encoding?: string, format?: string): string | Buffer;
    getPrivateKey(encoding?: string): string | Buffer;
    setPrivateKey(privateKey: string | Buffer, encoding?: string): void;
  }
}

declare module 'node:crypto' {
  export * from 'crypto';
}

declare module 'cluster' {
  export interface Worker {
    process: {
      pid: number;
    };
  }
  
  export const isPrimary: boolean;
  export const isWorker: boolean;
  
  export function fork(env?: Record<string, string>): Worker;
  export function on(event: 'exit', listener: (worker: Worker, code: number, signal: string) => void): void;
  export function on(event: 'online', listener: (worker: Worker) => void): void;
  export function on(event: 'disconnect', listener: (worker: Worker) => void): void;
}

declare module 'node:cluster' {
  export * from 'cluster';
}

declare module 'os' {
  export function cpus(): Array<{ model: string; speed: number; times: any }>;
  export function platform(): string;
}

declare module 'node:os' {
  export * from 'os';
}

declare namespace NodeJS {
  interface Process {
    argv: string[];
    exit(code?: number): never;
    env: {
      [key: string]: string | undefined;
    };
    pid: number;
    cwd(): string;
  }
  interface ProcessEnv {
    [key: string]: string | undefined;
  }
  type Timeout = ReturnType<typeof setTimeout>;
}

declare var process: NodeJS.Process;
declare var __dirname: string;
declare var __filename: string;

declare class Buffer {
  constructor(data: any);
  static from(data: string | ArrayBuffer, encoding?: string): Buffer;
  static alloc(size: number): Buffer;
  toString(encoding?: string): string;
  length: number;
}

