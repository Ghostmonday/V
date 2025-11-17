/**
 * Hardware-Accelerated Encryption Service
 * Detects and uses hardware acceleration (AES-NI) when available
 * Falls back to software implementation if hardware acceleration unavailable
 */

import crypto from 'crypto';
import { logInfo, logWarning } from '../shared/logger.js';
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
  
  try {
    if (algorithm.includes('gcm')) {
      // GCM mode (hardware-accelerated on x86/x64 with AES-NI)
      const cipher = crypto.createCipheriv(algorithm, key, iv);
      const encrypted = Buffer.concat([
        cipher.update(dataBuffer),
        cipher.final(),
      ]);
      const authTag = cipher.getAuthTag();
      
      return {
        encrypted,
        iv,
        authTag,
        algorithm,
        hardwareAccelerated: config.hardwareAccelerated,
      };
    } else {
      // CBC mode (software fallback)
      const cipher = crypto.createCipheriv(algorithm, key, iv);
      const encrypted = Buffer.concat([
        cipher.update(dataBuffer),
        cipher.final(),
      ]);
      
      return {
        encrypted,
        iv,
        algorithm,
        hardwareAccelerated: false,
      };
    }
  } catch (error: any) {
    throw new Error(`Hardware-accelerated encryption failed: ${error.message}`);
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
  
  try {
    if (algo.includes('gcm')) {
      // GCM mode
      if (!authTag) {
        throw new Error('Auth tag required for GCM mode');
      }
      
      const decipher = crypto.createDecipheriv(algo, key, iv);
      decipher.setAuthTag(authTag);
      
      return Buffer.concat([
        decipher.update(encrypted),
        decipher.final(),
      ]);
    } else {
      // CBC mode
      const decipher = crypto.createDecipheriv(algo, key, iv);
      return Buffer.concat([
        decipher.update(encrypted),
        decipher.final(),
      ]);
    }
  } catch (error: any) {
    throw new Error(`Hardware-accelerated decryption failed: ${error.message}`);
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
  const throughputMBps = (dataSize / (1024 * 1024)) / (durationMs / 1000);
  
  return {
    algorithm,
    hardwareAccelerated: config.hardwareAccelerated,
    durationMs,
    throughputMBps,
    fallbackAvailable: true, // Software fallback always available
  };
}

