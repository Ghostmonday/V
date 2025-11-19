/**
 * Hardware-Accelerated Encryption Service
 * Detects and uses hardware acceleration (AES-NI) when available
 * Falls back to software implementation if hardware acceleration unavailable
 */

import crypto from 'crypto';
import { logInfo, logWarning } from '../shared/logger-shared.js';
import { getEncryptionConfig, getOptimalEncryptionAlgorithm } from '../config/encryption-config.js';

/**
 * Encryption algorithm preferences (hardware-accelerated first)
 */
const ENCRYPTION_ALGORITHMS = {
  // Hardware-accelerated (AES-NI on x86/x64)
  hardware: ['aes-256-gcm', 'aes-192-gcm', 'aes-128-gcm'],
  // Software fallback
  software: ['aes-256-cbc', 'aes-192-cbc', 'aes-128-cbc'],
};

/**
 * Detect hardware acceleration capabilities
 * DEPRECATED: Use getEncryptionConfig() from encryption-config.ts instead
 * Kept for backward compatibility
 */
export function detectHardwareAcceleration(): {
  hardwareAccelerated: boolean;
  preferredAlgorithm: string;
  detected: boolean;
} {
  const config = getEncryptionConfig();
  return {
    hardwareAccelerated: config.hardwareAccelerated,
    preferredAlgorithm: config.preferredAlgorithm,
    detected: config.detected,
  };
}

/**
 * Hardware-accelerated encryption
 * Uses AES-NI when available, falls back to software otherwise
 */
export async function encryptWithHardwareAcceleration(
  data: Buffer | string,
  key: Buffer
): Promise<{
  encrypted: Buffer;
  iv: Buffer;
  authTag?: Buffer;
  algorithm: string;
  hardwareAccelerated: boolean;
}> {
  const algorithm = getOptimalEncryptionAlgorithm();
  const config = getEncryptionConfig();
  const iv = crypto.randomBytes(16);

  const dataBuffer = typeof data === 'string' ? Buffer.from(data, 'utf8') : data;

  // Validate inputs
  if (!dataBuffer || dataBuffer.length === 0) {
    throw new Error('Invalid input: data buffer is empty');
  }

  if (!key || key.length < 16) {
    throw new Error('Invalid key: key must be at least 16 bytes');
  }

  try {
    if (algorithm.includes('gcm')) {
      // GCM mode (hardware-accelerated on x86/x64 with AES-NI)
      try {
        const cipher = crypto.createCipheriv(algorithm, key, iv);
        const encrypted = Buffer.concat([cipher.update(dataBuffer), cipher.final()]);
        const authTag = cipher.getAuthTag();

        return {
          encrypted,
          iv,
          authTag,
          algorithm,
          hardwareAccelerated: config.hardwareAccelerated,
        };
      } catch (gcmError: any) {
        // Fallback to software encryption if hardware acceleration fails
        logWarning('Hardware-accelerated GCM encryption failed, falling back to software', {
          error: gcmError.message,
          algorithm,
        });

        // Try software fallback (CBC mode)
        return await encryptWithSoftwareFallback(dataBuffer, key, iv);
      }
    } else {
      // CBC mode (software fallback)
      return await encryptWithSoftwareFallback(dataBuffer, key, iv);
    }
  } catch (error: any) {
    // Comprehensive error handling
    const errorMessage = error.message || 'Unknown encryption error';
    const errorCode = error.code || 'ENCRYPTION_ERROR';

    logWarning('Encryption failed, attempting software fallback', {
      error: errorMessage,
      errorCode,
      algorithm,
      hardwareAccelerated: config.hardwareAccelerated,
    });

    // Final fallback attempt
    try {
      return await encryptWithSoftwareFallback(dataBuffer, key, iv);
    } catch (fallbackError: any) {
      throw new Error(
        `Hardware-accelerated encryption failed: ${errorMessage}. Fallback also failed: ${fallbackError.message}`
      );
    }
  }
}

/**
 * Software fallback encryption (CBC mode)
 * Used when hardware acceleration fails or is unavailable
 */
async function encryptWithSoftwareFallback(
  dataBuffer: Buffer,
  key: Buffer,
  iv: Buffer
): Promise<{
  encrypted: Buffer;
  iv: Buffer;
  algorithm: string;
  hardwareAccelerated: boolean;
}> {
  try {
    // Use AES-256-CBC as software fallback
    const fallbackAlgorithm = 'aes-256-cbc';
    const cipher = crypto.createCipheriv(fallbackAlgorithm, key, iv);
    const encrypted = Buffer.concat([cipher.update(dataBuffer), cipher.final()]);

    logInfo('Using software encryption fallback', {
      algorithm: fallbackAlgorithm,
    });

    return {
      encrypted,
      iv,
      algorithm: fallbackAlgorithm,
      hardwareAccelerated: false,
    };
  } catch (error: any) {
    throw new Error(`Software encryption fallback failed: ${error.message}`);
  }
}

/**
 * Hardware-accelerated decryption
 */
export async function decryptWithHardwareAcceleration(
  encrypted: Buffer,
  key: Buffer,
  iv: Buffer,
  authTag?: Buffer,
  algorithm?: string
): Promise<Buffer> {
  const algo = algorithm || getOptimalEncryptionAlgorithm();

  // Validate inputs
  if (!encrypted || encrypted.length === 0) {
    throw new Error('Invalid input: encrypted buffer is empty');
  }

  if (!key || key.length < 16) {
    throw new Error('Invalid key: key must be at least 16 bytes');
  }

  if (!iv || iv.length < 16) {
    throw new Error('Invalid IV: IV must be at least 16 bytes');
  }

  try {
    if (algo.includes('gcm')) {
      // GCM mode
      if (!authTag) {
        throw new Error('Auth tag required for GCM mode');
      }

      if (authTag.length !== 16) {
        throw new Error('Invalid auth tag: must be 16 bytes');
      }

      try {
        const decipher = crypto.createDecipheriv(algo, key, iv);
        decipher.setAuthTag(authTag);

        const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);

        return decrypted;
      } catch (gcmError: any) {
        // If GCM decryption fails, it might be corrupted data
        // Don't fallback - GCM provides authentication, so failure means tampering
        logWarning('GCM decryption failed - possible tampering or corruption', {
          error: gcmError.message,
          algorithm: algo,
        });
        throw new Error(
          `GCM decryption failed: ${gcmError.message}. Data may be corrupted or tampered.`
        );
      }
    } else {
      // CBC mode (software fallback)
      try {
        const decipher = crypto.createDecipheriv(algo, key, iv);
        return Buffer.concat([decipher.update(encrypted), decipher.final()]);
      } catch (cbcError: any) {
        // Comprehensive error handling for CBC mode
        const errorMessage = cbcError.message || 'Unknown decryption error';
        const errorCode = cbcError.code || 'DECRYPTION_ERROR';

        logWarning('CBC decryption failed', {
          error: errorMessage,
          errorCode,
          algorithm: algo,
        });

        throw new Error(`Hardware-accelerated decryption failed: ${errorMessage}`);
      }
    }
  } catch (error: any) {
    // Re-throw if it's already a formatted error
    if (error.message && error.message.includes('decryption failed')) {
      throw error;
    }

    // Format unknown errors
    throw new Error(`Hardware-accelerated decryption failed: ${error.message || 'Unknown error'}`);
  }
}

/**
 * Benchmark encryption performance
 * Useful for detecting hardware acceleration improvements
 */
export async function benchmarkEncryption(
  dataSize: number = 1024 * 1024 // 1MB default
): Promise<{
  algorithm: string;
  hardwareAccelerated: boolean;
  durationMs: number;
  throughputMBps: number;
  fallbackAvailable: boolean;
}> {
  const config = getEncryptionConfig();
  const algorithm = config.preferredAlgorithm;
  const data = Buffer.alloc(dataSize, 'test');
  const key = crypto.randomBytes(32);

  const startTime = process.hrtime.bigint();

  await encryptWithHardwareAcceleration(data, key);

  const endTime = process.hrtime.bigint();
  const durationMs = Number(endTime - startTime) / 1_000_000;
  const throughputMBps = dataSize / (1024 * 1024) / (durationMs / 1000);

  return {
    algorithm,
    hardwareAccelerated: config.hardwareAccelerated,
    durationMs,
    throughputMBps,
    fallbackAvailable: true, // Software fallback always available
  };
}
