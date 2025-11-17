/**
 * User Authentication Service Tests
 * Tests token generation, password hashing, and authentication flows
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { issueToken, authenticate, encryptSensitiveData, decryptSensitiveData } from '../user-authentication-service.js';
import bcrypt from 'bcrypt';
import argon2 from 'argon2';

// Mock dependencies
vi.mock('../shared/supabase-client.js', () => ({
  supabase: {
    auth: {
      signInWithPassword: vi.fn(),
    },
  },
}));

vi.mock('bcrypt', () => ({
  default: {
    hash: vi.fn(),
    compare: vi.fn(),
  },
}));

vi.mock('argon2', () => ({
  default: {
    hash: vi.fn(),
    verify: vi.fn(),
  },
}));

describe('User Authentication Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.JWT_SECRET = 'test-secret-key-for-testing-only';
  });

  describe('issueToken', () => {
    it('should generate a valid JWT token', () => {
      const user = { id: 'user-123', tier: 'free', handle: 'testuser' };
      const token = issueToken(user);
      
      expect(token).toBeDefined();
      expect(typeof token).toBe('string');
      expect(token.split('.')).toHaveLength(3); // JWT has 3 parts
    });

    it('should throw error if JWT_SECRET is not set', () => {
      delete process.env.JWT_SECRET;
      
      const user = { id: 'user-123' };
      expect(() => issueToken(user)).toThrow('JWT_SECRET is not set');
    });

    it('should include user data in token', () => {
      const user = { id: 'user-123', tier: 'pro', handle: 'testuser' };
      const token = issueToken(user);
      
      // Decode token (without verification for testing)
      const parts = token.split('.');
      const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
      
      expect(payload.id).toBe(user.id);
      expect(payload.tier).toBe(user.tier);
      expect(payload.handle).toBe(user.handle);
    });
  });

  describe('authenticate', () => {
    it('should authenticate valid credentials', async () => {
      const { supabase } = await import('../shared/supabase-client.js');
      
      vi.mocked(supabase.auth.signInWithPassword).mockResolvedValue({
        data: {
          user: {
            id: 'user-123',
            email: 'test@example.com',
          },
        },
        error: null,
      } as any);

      const result = await authenticate('test@example.com', 'password123');
      
      expect(result).toBeDefined();
      expect(result.id).toBe('user-123');
      expect(supabase.auth.signInWithPassword).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123',
      });
    });

    it('should throw error for invalid credentials', async () => {
      const { supabase } = await import('../shared/supabase-client.js');
      
      vi.mocked(supabase.auth.signInWithPassword).mockResolvedValue({
        data: { user: null },
        error: { message: 'Invalid credentials' },
      } as any);

      await expect(authenticate('test@example.com', 'wrong')).rejects.toThrow('Invalid credentials');
    });
  });

  describe('encryptSensitiveData / decryptSensitiveData', () => {
    it('should encrypt and decrypt data correctly', async () => {
      const plaintext = 'sensitive-data-123';
      
      const encrypted = await encryptSensitiveData(plaintext);
      expect(encrypted).toBeDefined();
      expect(encrypted).not.toBe(plaintext);
      expect(typeof encrypted).toBe('string');
      
      const decrypted = await decryptSensitiveData(encrypted);
      expect(decrypted).toBe(plaintext);
    });

    it('should produce different ciphertext for same plaintext (IV randomness)', async () => {
      const plaintext = 'test-data';
      
      const encrypted1 = await encryptSensitiveData(plaintext);
      const encrypted2 = await encryptSensitiveData(plaintext);
      
      // Should be different due to random IV
      expect(encrypted1).not.toBe(encrypted2);
      
      // But both should decrypt to same plaintext
      expect(await decryptSensitiveData(encrypted1)).toBe(plaintext);
      expect(await decryptSensitiveData(encrypted2)).toBe(plaintext);
    });

    it('should handle empty strings', async () => {
      const encrypted = await encryptSensitiveData('');
      const decrypted = await decryptSensitiveData(encrypted);
      expect(decrypted).toBe('');
    });
  });

  describe('Password Hashing', () => {
    it('should hash passwords with bcrypt', async () => {
      const password = 'test-password-123';
      const hash = await bcrypt.hash(password, 10);
      
      expect(hash).toBeDefined();
      expect(hash).not.toBe(password);
      expect(hash.startsWith('$2')).toBe(true); // bcrypt hash format
    });

    it('should verify bcrypt hashes correctly', async () => {
      const password = 'test-password-123';
      const hash = await bcrypt.hash(password, 10);
      
      const isValid = await bcrypt.compare(password, hash);
      expect(isValid).toBe(true);
      
      const isInvalid = await bcrypt.compare('wrong-password', hash);
      expect(isInvalid).toBe(false);
    });

    it('should hash passwords with argon2', async () => {
      const password = 'test-password-123';
      const hash = await argon2.hash(password);
      
      expect(hash).toBeDefined();
      expect(hash).not.toBe(password);
      expect(typeof hash).toBe('string');
    });

    it('should verify argon2 hashes correctly', async () => {
      const password = 'test-password-123';
      const hash = await argon2.hash(password);
      
      const isValid = await argon2.verify(hash, password);
      expect(isValid).toBe(true);
      
      const isInvalid = await argon2.verify(hash, 'wrong-password');
      expect(isInvalid).toBe(false);
    });
  });
});

