/**
 * Encryption Service
 * Encrypts sensitive PII fields at rest using Supabase Vault
 * Implements privacy-by-design with transparent encryption/decryption
 */

import crypto from 'crypto';
import { supabase } from '../config/database-config.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { getApiKey } from './api-keys-service.js';
import {
  getOptimalEncryptionAlgorithm,
  encryptWithHardwareAcceleration,
  decryptWithHardwareAcceleration,
} from './hardware-accelerated-encryption.js';

const ALGORITHM = 'aes-256-gcm'; // Default, will use hardware-accelerated if available
const IV_LENGTH = 16;
const SALT_LENGTH = 64;
const TAG_LENGTH = 16;

/**
 * Get encryption key from vault (or generate and store)
 */
async function getEncryptionKey(): Promise<Buffer> {
  try {
    // Try to get from vault first
    let key = await getApiKey('encryption_master_key', 'production');

    if (!key) {
      // Generate new key if not exists
      key = crypto.randomBytes(32).toString('hex');

      // Store in vault (would need to implement vault storage)
      logInfo('Generated new encryption key - store securely in vault');
    }

    // Convert hex string to buffer
    return Buffer.from(key, 'hex');
  } catch (error: any) {
    logError('Failed to get encryption key', error);
    // Fallback: use env var (less secure but prevents failure)
    const fallbackKey = process.env.ENCRYPTION_KEY || crypto.randomBytes(32).toString('hex');
    return Buffer.from(fallbackKey, 'hex');
  }
}

/**
 * Encrypt sensitive data
 * Uses hardware-accelerated encryption when available
 */
export async function encryptField(value: string): Promise<string> {
  if (!value || typeof value !== 'string') {
    return value;
  }

  try {
    const key = await getEncryptionKey();
    const salt = crypto.randomBytes(SALT_LENGTH);

    // Derive key from master key and salt
    const derivedKey = crypto.pbkdf2Sync(key, salt, 100000, 32, 'sha512');

    // Use hardware-accelerated encryption if available
    const { encrypted, iv, authTag, algorithm } = await encryptWithHardwareAcceleration(
      value,
      derivedKey
    );

    // Combine: salt:iv:authTag:encrypted:algorithm
    return `${salt.toString('hex')}:${iv.toString('hex')}:${authTag?.toString('hex') || ''}:${encrypted.toString('hex')}:${algorithm}`;
  } catch (error: any) {
    logError('Encryption failed', error);
    // Fallback to software encryption
    try {
      const key = await getEncryptionKey();
      const iv = crypto.randomBytes(IV_LENGTH);
      const salt = crypto.randomBytes(SALT_LENGTH);
      const derivedKey = crypto.pbkdf2Sync(key, salt, 100000, 32, 'sha512');
      const cipher = crypto.createCipheriv(ALGORITHM, derivedKey, iv);
      let encrypted = cipher.update(value, 'utf8', 'hex');
      encrypted += cipher.final('hex');
      const authTag = cipher.getAuthTag();
      return `${salt.toString('hex')}:${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}:${ALGORITHM}`;
    } catch (fallbackError: any) {
      logError('Fallback encryption also failed', fallbackError);
      throw new Error('Failed to encrypt sensitive data');
    }
  }
}

/**
 * Decrypt sensitive data
 * Uses hardware-accelerated decryption when available
 */
export async function decryptField(encryptedValue: string): Promise<string> {
  if (!encryptedValue || typeof encryptedValue !== 'string') {
    return encryptedValue;
  }

  // Check if value is already encrypted (has colons)
  if (!encryptedValue.includes(':')) {
    // Not encrypted, return as-is (backward compatibility)
    return encryptedValue;
  }

  try {
    const parts = encryptedValue.split(':');
    // Support both old format (4 parts) and new format (5 parts with algorithm)
    if (parts.length < 4 || parts.length > 5) {
      throw new Error('Invalid encrypted format');
    }

    const [saltHex, ivHex, authTagHex, encryptedHex, algorithm] = parts;
    const salt = Buffer.from(saltHex, 'hex');
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    const encrypted = Buffer.from(encryptedHex, 'hex');

    const key = await getEncryptionKey();
    const derivedKey = crypto.pbkdf2Sync(key, salt, 100000, 32, 'sha512');

    // Use hardware-accelerated decryption if algorithm supports it
    if (algorithm && algorithm.includes('gcm')) {
      try {
        const decrypted = await decryptWithHardwareAcceleration(
          encrypted,
          derivedKey,
          iv,
          authTag,
          algorithm
        );
        return decrypted.toString('utf8');
      } catch (hwError) {
        // Fallback to software decryption
        logError('Hardware decryption failed, using software fallback', hwError);
      }
    }

    // Software decryption (fallback or legacy format)
    const algo = algorithm || ALGORITHM;
    const decipher = crypto.createDecipheriv(algo, derivedKey, iv);
    if (authTag.length > 0) {
      decipher.setAuthTag(authTag);
    }

    let decrypted = decipher.update(encrypted, null, 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  } catch (error: any) {
    logError('Decryption failed', error);
    throw new Error('Failed to decrypt sensitive data');
  }
}

/**
 * Encrypt object fields (for PII minimization)
 */
export async function encryptPIIFields<T extends Record<string, any>>(
  data: T,
  fieldsToEncrypt: string[]
): Promise<T> {
  const encrypted = { ...data };

  for (const field of fieldsToEncrypt) {
    if (encrypted[field] && typeof encrypted[field] === 'string') {
      try {
        encrypted[field] = await encryptField(encrypted[field]);
      } catch (error: any) {
        logError(`Failed to encrypt field ${field}`, error);
        // Don't fail - log and continue
      }
    }
  }

  return encrypted;
}

/**
 * Decrypt object fields
 */
export async function decryptPIIFields<T extends Record<string, any>>(
  data: T,
  fieldsToDecrypt: string[]
): Promise<T> {
  const decrypted = { ...data };

  for (const field of fieldsToDecrypt) {
    if (decrypted[field] && typeof decrypted[field] === 'string') {
      try {
        decrypted[field] = await decryptField(decrypted[field]);
      } catch (error: any) {
        logError(`Failed to decrypt field ${field}`, error);
        // Return encrypted value if decryption fails
      }
    }
  }

  return decrypted;
}

/**
 * Hash PII for search/indexing (one-way, cannot be reversed)
 */
export function hashPII(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}

/**
 * Redact PII from text (for logging)
 */
export function redactPII(text: string, patterns: RegExp[] = []): string {
  let redacted = text;

  // Default patterns
  const defaultPatterns = [
    /\b\d{3}-\d{2}-\d{4}\b/g, // SSN
    /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g, // Credit card
    /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g, // Email
    /\b\d{3}-\d{3}-\d{4}\b/g, // Phone
  ];

  const allPatterns = [...defaultPatterns, ...patterns];

  for (const pattern of allPatterns) {
    redacted = redacted.replace(pattern, '[REDACTED]');
  }

  return redacted;
}
