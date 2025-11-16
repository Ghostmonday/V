/**
 * Anonymization Tests
 * Tests PII anonymization utilities
 */

import { describe, it, expect } from 'vitest';
import {
  hashSHA256,
  hashWithSalt,
  anonymizeUserId,
  anonymizeEmail,
  anonymizePhone,
  anonymizePII,
  generateUserSalt,
} from '../../packages/core/src/utils.js';

describe('Anonymization Utilities', () => {
  it('should hash strings with SHA-256', () => {
    const input = 'test input';
    const hash = hashSHA256(input);
    
    expect(hash).toBeDefined();
    expect(typeof hash).toBe('string');
    expect(hash.length).toBe(64); // SHA-256 produces 64 hex characters
  });

  it('should produce consistent hashes for same input', () => {
    const input = 'test input';
    const hash1 = hashSHA256(input);
    const hash2 = hashSHA256(input);
    
    expect(hash1).toBe(hash2);
  });

  it('should hash with salt', () => {
    const input = 'test input';
    const { hash, salt } = hashWithSalt(input);
    
    expect(hash).toBeDefined();
    expect(salt).toBeDefined();
    expect(hash.length).toBe(64);
    expect(salt.length).toBeGreaterThan(0);
  });

  it('should produce same hash with same salt', () => {
    const input = 'test input';
    const salt = 'test-salt';
    
    const { hash: hash1 } = hashWithSalt(input, salt);
    const { hash: hash2 } = hashWithSalt(input, salt);
    
    expect(hash1).toBe(hash2);
  });

  it('should anonymize user IDs', () => {
    const userId = '123e4567-e89b-12d3-a456-426614174000';
    const anonymized = anonymizeUserId(userId);
    
    expect(anonymized).toBeDefined();
    expect(anonymized).not.toBe(userId);
    expect(anonymized.length).toBe(64); // SHA-256 hash length
  });

  it('should anonymize emails', () => {
    const email = 'test@example.com';
    const anonymized = anonymizeEmail(email);
    
    expect(anonymized).toBeDefined();
    expect(anonymized).not.toBe(email);
    expect(anonymized.length).toBe(64);
  });

  it('should anonymize phone numbers', () => {
    const phone = '+1-555-123-4567';
    const anonymized = anonymizePhone(phone);
    
    expect(anonymized).toBeDefined();
    expect(anonymized).not.toBe(phone);
    expect(anonymized.length).toBe(64);
  });

  it('should anonymize PII objects', () => {
    const data = {
      email: 'test@example.com',
      phone: '+1-555-123-4567',
      userId: '123e4567-e89b-12d3-a456-426614174000',
      name: 'John Doe', // Should not be anonymized (not in fields list)
    };
    
    const anonymized = anonymizePII(data, ['email', 'phone', 'userId']);
    
    expect(anonymized.email).not.toBe(data.email);
    expect(anonymized.phone).not.toBe(data.phone);
    expect(anonymized.userId).not.toBe(data.userId);
    expect(anonymized.name).toBe(data.name); // Not anonymized
  });

  it('should generate consistent user salt', () => {
    const userId = '123e4567-e89b-12d3-a456-426614174000';
    const salt1 = generateUserSalt(userId);
    const salt2 = generateUserSalt(userId);
    
    expect(salt1).toBe(salt2);
    expect(salt1).toContain('user_salt_');
  });
});

