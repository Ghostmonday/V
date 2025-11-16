/**
 * Core Utilities
 * Provides anonymization and hashing utilities for PII protection
 */

import { createHash, randomBytes } from 'crypto';

/**
 * Hash a string using SHA-256
 * @param input - String to hash
 * @returns Hexadecimal hash string
 */
export function hashSHA256(input: string): string {
  return createHash('sha256').update(input).digest('hex');
}

/**
 * Hash a string with salt using SHA-256
 * @param input - String to hash
 * @param salt - Salt value (if not provided, generates random salt)
 * @returns Object with hash and salt
 */
export function hashWithSalt(input: string, salt?: string): { hash: string; salt: string } {
  const usedSalt = salt || randomBytes(16).toString('hex');
  const hash = createHash('sha256').update(input + usedSalt).digest('hex');
  return { hash, salt: usedSalt };
}

/**
 * Anonymize user ID for analytics
 * Creates a consistent hash that can be used for analytics without exposing PII
 * @param userId - User UUID
 * @param salt - Optional salt (use consistent salt for same user across sessions)
 * @returns Anonymized hash
 */
export function anonymizeUserId(userId: string, salt?: string): string {
  const { hash } = hashWithSalt(userId, salt);
  return hash;
}

/**
 * Anonymize email address
 * Hashes email for analytics while maintaining uniqueness
 * @param email - Email address
 * @param salt - Optional salt
 * @returns Anonymized hash
 */
export function anonymizeEmail(email: string, salt?: string): string {
  const normalizedEmail = email.toLowerCase().trim();
  const { hash } = hashWithSalt(normalizedEmail, salt);
  return hash;
}

/**
 * Anonymize phone number
 * Hashes phone number for analytics
 * @param phone - Phone number
 * @param salt - Optional salt
 * @returns Anonymized hash
 */
export function anonymizePhone(phone: string, salt?: string): string {
  // Normalize phone number (remove formatting)
  const normalizedPhone = phone.replace(/\D/g, '');
  const { hash } = hashWithSalt(normalizedPhone, salt);
  return hash;
}

/**
 * Anonymize PII object
 * Anonymizes all PII fields in an object
 * @param data - Object containing PII
 * @param fields - Fields to anonymize (default: ['email', 'phone', 'userId'])
 * @param salt - Optional salt for consistent hashing
 * @returns Object with anonymized fields
 */
export function anonymizePII<T extends Record<string, any>>(
  data: T,
  fields: string[] = ['email', 'phone', 'userId'],
  salt?: string
): T {
  const anonymized = { ...data };
  
  for (const field of fields) {
    if (anonymized[field] && typeof anonymized[field] === 'string') {
      if (field === 'email') {
        anonymized[field] = anonymizeEmail(anonymized[field], salt) as any;
      } else if (field === 'phone') {
        anonymized[field] = anonymizePhone(anonymized[field], salt) as any;
      } else if (field === 'userId' || field === 'user_id') {
        anonymized[field] = anonymizeUserId(anonymized[field], salt) as any;
      } else {
        anonymized[field] = hashSHA256(anonymized[field]) as any;
      }
    }
  }
  
  return anonymized;
}

/**
 * Generate consistent salt for user
 * Creates a salt based on user ID that can be reused
 * @param userId - User ID
 * @returns Salt string
 */
export function generateUserSalt(userId: string): string {
  // Use a fixed prefix + user ID hash for consistent salting
  return `user_salt_${hashSHA256(userId).substring(0, 16)}`;
}

