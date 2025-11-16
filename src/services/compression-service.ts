/**
 * Compression and Storage Function
 * Implements adaptive compression selection based on payload type detection.
 * Uses MIME type for detection if provided, falling back to basic type checks.
 * Compression algorithms: gzip (streaming), LZ4 (sync), Snappy (sync).
 * Integrates with Supabase Storage for upload with compression metadata.
 */

import { Readable } from 'stream';
import { createGzip } from 'zlib';
import * as lz4 from 'lz4';
import * as snappy from 'snappyjs';
import { supabase } from '../config/db.js';
import { logInfo } from '../shared/logger.js';

/**
 * Helper to convert ReadableStream to Uint8Array
 */
async function streamToUint8Array(stream: NodeJS.ReadableStream): Promise<Uint8Array> {
  const chunks: Buffer[] = [];
  
  for await (const chunk of stream) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  
  return new Uint8Array(Buffer.concat(chunks));
}

/**
 * Benchmark function to log ratio and latency with low overhead (<10ms)
 * Uses performance.now() for precise timing
 */
function compressionBenchmark(algo: string, ratio: number, latency: number): void {
  logInfo(`[Compression Benchmark] Algorithm: ${algo}, Ratio: ${ratio.toFixed(4)}, Latency: ${latency.toFixed(2)}ms`);
}

/**
 * Compress and store payload to Supabase Storage
 * 
 * @param payload - String or Uint8Array to compress
 * @param bucket - Supabase Storage bucket name
 * @param path - Storage path for the file
 * @param options - Optional configuration with mime type
 * @returns Promise resolving to storage path data
 */
export async function compressAndStore(
  payload: string | Uint8Array,
  bucket: string,
  path: string,
  options: { mime?: string } = {}
): Promise<{ path: string }> {
  // Detect payload type
  let type: 'text' | 'binary' | 'voice';
  const mime = options.mime;
  
  if (mime) {
    if (mime.startsWith('text/')) {
      type = 'text';
    } else if (mime.startsWith('audio/')) {
      type = 'voice';
    } else {
      type = 'binary';
    }
  } else {
    // Default: string = text, Uint8Array = binary
    type = typeof payload === 'string' ? 'text' : 'binary';
  }

  // Prepare bytes and original size
  const bytes = typeof payload === 'string' 
    ? new TextEncoder().encode(payload) 
    : payload instanceof Uint8Array 
      ? payload 
      : new Uint8Array(Buffer.from(payload));
  
  const originalSize = bytes.length;

  // Select algorithm and compress
  let algo: string;
  let compressed: Uint8Array;
  const start = performance.now();

  if (type === 'text') {
    // Use gzip streaming for text
    algo = 'gzip';
    const inputBuffer = Buffer.from(bytes);
    const inputStream = Readable.from([inputBuffer]);
    const compressStream = createGzip();
    const compressedStream = inputStream.pipe(compressStream);
    compressed = await streamToUint8Array(compressedStream);
  } else if (type === 'binary') {
    // Use LZ4 for binary data
    algo = 'lz4';
    const buffer = Buffer.from(bytes);
    const compressedBuffer = lz4.encode(buffer);
    compressed = new Uint8Array(compressedBuffer);
  } else {
    // Use Snappy for voice/audio data
    algo = 'snappy';
    const buffer = Buffer.from(bytes);
    compressed = snappy.compress(buffer);
  }

  const end = performance.now();
  const latency = end - start;
  const ratio = compressed.length / originalSize;

  // Benchmark logging
  compressionBenchmark(algo, ratio, latency);

  // Store in Supabase Storage
  const { data, error } = await supabase.storage
    .from(bucket)
    .upload(path, compressed, {
      contentType: 'application/octet-stream',
      upsert: true,
      metadata: { compression: algo },
    });

  if (error) {
    throw new Error(`Failed to upload to Supabase Storage: ${error.message}`);
  }

  if (!data) {
    throw new Error('Upload succeeded but no data returned');
  }

  return data;
}

