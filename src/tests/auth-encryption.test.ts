/**
 * Auth Encryption Tests
 * Tests AES-256 encryption for sensitive user data
 */

import { describe, it, expect } from 'vitest';
import {
  encryptSensitiveData,
  decryptSensitiveData,
  encryptUserEmail,
  decryptUserEmail,
  encryptUserPhone,
  decryptUserPhone,
} from '../services/user-authentication-service.js';

describe('Auth Encryption Service', () => {
  it('should encrypt and decrypt sensitive data', async () => {
    const plaintext = 'sensitive information';
    
    const encrypted = await encryptSensitiveData(plaintext);
    expect(encrypted).toBeDefined();
    expect(typeof encrypted).toBe('string');
    expect(encrypted).not.toBe(plaintext);
    
    const decrypted = await decryptSensitiveData(encrypted);
    expect(decrypted).toBe(plaintext);
  });

  it('should encrypt and decrypt user email', async () => {
    const email = 'test@example.com';
    
    const encrypted = await encryptUserEmail(email);
    expect(encrypted).toBeDefined();
    expect(encrypted).not.toBe(email);
    
    const decrypted = await decryptUserEmail(encrypted);
    expect(decrypted.toLowerCase().trim()).toBe(email.toLowerCase().trim());
  });

  it('should encrypt and decrypt user phone', async () => {
    const phone = '+1-555-123-4567';
    
    const encrypted = await encryptUserPhone(phone);
    expect(encrypted).toBeDefined();
    expect(encrypted).not.toBe(phone);
    
    const decrypted = await decryptUserPhone(encrypted);
    // Phone is normalized (digits only) before encryption
    expect(decrypted).toBe(phone.replace(/\D/g, ''));
  });

  it('should produce different ciphertexts for same plaintext (IV randomization)', async () => {
    const plaintext = 'test data';
    
    const encrypted1 = await encryptSensitiveData(plaintext);
    const encrypted2 = await encryptSensitiveData(plaintext);
    
    // Same plaintext should produce different ciphertexts due to random IV
    expect(encrypted1).not.toBe(encrypted2);
    
    // But both should decrypt to the same plaintext
    const decrypted1 = await decryptSensitiveData(encrypted1);
    const decrypted2 = await decryptSensitiveData(encrypted2);
    expect(decrypted1).toBe(plaintext);
    expect(decrypted2).toBe(plaintext);
  });
});

