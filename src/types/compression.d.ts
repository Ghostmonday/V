/**
 * Type declarations for compression libraries
 */

declare module 'lz4' {
  export function encode(input: Buffer): Buffer;
  export function decode(input: Buffer): Buffer;
  export function createEncoderStream(): NodeJS.ReadWriteStream;
  export function createDecoderStream(): NodeJS.ReadWriteStream;
}

declare module 'snappyjs' {
  export function compress(input: Buffer | Uint8Array): Uint8Array;
  export function uncompress(input: Buffer | Uint8Array): Uint8Array;
}

