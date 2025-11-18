/**
 * Refresh Token Service Tests
 * Tests refresh token generation, rotation, and revocation
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  issueTokenPair,
  rotateRefreshToken,
  revokeRefreshToken,
} from '../refresh-token-service.js';
import { createHash } from 'crypto';

// Mock Supabase
const mockSupabase = {
  from: vi.fn(),
};

const mockSupabaseAdmin = {
  auth: {
    updateUserById: vi.fn(),
  },
};

vi.mock('../shared/supabase-client.js', () => ({
  supabase: mockSupabase,
}));

vi.mock('../../config/supabase-admin.js', () => ({
  supabaseAdmin: mockSupabaseAdmin,
}));

vi.mock('../shared/logger.js', () => ({
  logError: vi.fn(),
  logInfo: vi.fn(),
  logWarning: vi.fn(),
}));

describe('Refresh Token Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('issueTokenPair', () => {
    it('should generate access token and refresh token pair', async () => {
      const mockInsert = vi.fn().mockReturnValue({
        select: vi.fn().mockReturnValue({
          single: vi.fn().mockResolvedValue({
            data: {
              id: 'token-123',
              user_id: 'user-123',
              token_hash: 'hashed-token',
              expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
            },
            error: null,
          }),
        }),
      });

      mockSupabase.from.mockReturnValue({
        insert: mockInsert,
      } as any);

      const result = await issueTokenPair('user-123', '127.0.0.1', 'test-agent');

      expect(result).toBeDefined();
      expect(result.accessToken).toBeDefined();
      expect(result.refreshToken).toBeDefined();
      expect(result.expiresAt).toBeInstanceOf(Date);
      expect(mockInsert).toHaveBeenCalled();
    });

    it('should hash refresh token before storage', async () => {
      const mockInsert = vi.fn().mockReturnValue({
        select: vi.fn().mockReturnValue({
          single: vi.fn().mockResolvedValue({
            data: {
              id: 'token-123',
              user_id: 'user-123',
              token_hash: 'hashed-token',
              expires_at: new Date().toISOString(),
            },
            error: null,
          }),
        }),
      });

      mockSupabase.from.mockReturnValue({
        insert: mockInsert,
      } as any);

      await issueTokenPair('user-123', '127.0.0.1', 'test-agent');

      const insertCall = mockInsert.mock.calls[0][0];
      expect(insertCall.token_hash).toBeDefined();
      expect(insertCall.token_hash).not.toBe(insertCall.refreshToken); // Should be hashed
      expect(insertCall.token_hash.length).toBe(64); // SHA-256 hash length
    });
  });

  describe('rotateRefreshToken', () => {
    it('should rotate refresh token and issue new pair', async () => {
      const oldTokenHash = createHash('sha256').update('old-refresh-token').digest('hex');
      const newTokenHash = createHash('sha256').update('new-refresh-token').digest('hex');

      const mockSelect = vi.fn().mockReturnValue({
        eq: vi.fn().mockReturnValue({
          single: vi.fn().mockResolvedValue({
            data: {
              id: 'token-123',
              user_id: 'user-123',
              token_hash: oldTokenHash,
              expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
              last_used_at: null,
            },
            error: null,
          }),
        }),
      });

      const mockUpdate = vi.fn().mockReturnValue({
        eq: vi.fn().mockResolvedValue({ data: null, error: null }),
      });

      const mockInsert = vi.fn().mockReturnValue({
        select: vi.fn().mockReturnValue({
          single: vi.fn().mockResolvedValue({
            data: {
              id: 'token-456',
              user_id: 'user-123',
              token_hash: newTokenHash,
              expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
            },
            error: null,
          }),
        }),
      });

      mockSupabase.from.mockImplementation((table: string) => {
        if (table === 'refresh_tokens') {
          return {
            select: mockSelect,
            update: mockUpdate,
            insert: mockInsert,
          } as any;
        }
        return {} as any;
      });

      // Mock token hash verification
      vi.spyOn(createHash('sha256'), 'update').mockReturnValue({
        digest: vi.fn().mockReturnValue(oldTokenHash),
      } as any);

      const result = await rotateRefreshToken('old-refresh-token', '127.0.0.1', 'test-agent');

      expect(result).toBeDefined();
      expect(result?.accessToken).toBeDefined();
      expect(result?.refreshToken).toBeDefined();
      expect(mockUpdate).toHaveBeenCalled(); // Old token should be invalidated
      expect(mockInsert).toHaveBeenCalled(); // New token should be created
    });

    it('should reject invalid refresh token', async () => {
      const mockSelect = vi.fn().mockReturnValue({
        eq: vi.fn().mockReturnValue({
          single: vi.fn().mockResolvedValue({
            data: null,
            error: { message: 'Not found' },
          }),
        }),
      });

      mockSupabase.from.mockReturnValue({
        select: mockSelect,
      } as any);

      const result = await rotateRefreshToken('invalid-token', '127.0.0.1', 'test-agent');

      expect(result).toBeNull();
    });

    it('should reject expired refresh token', async () => {
      const expiredDate = new Date(Date.now() - 24 * 60 * 60 * 1000); // 1 day ago
      const tokenHash = createHash('sha256').update('expired-token').digest('hex');

      const mockSelect = vi.fn().mockReturnValue({
        eq: vi.fn().mockReturnValue({
          single: vi.fn().mockResolvedValue({
            data: {
              id: 'token-123',
              user_id: 'user-123',
              token_hash: tokenHash,
              expires_at: expiredDate.toISOString(),
            },
            error: null,
          }),
        }),
      });

      mockSupabase.from.mockReturnValue({
        select: mockSelect,
      } as any);

      const result = await rotateRefreshToken('expired-token', '127.0.0.1', 'test-agent');

      expect(result).toBeNull();
    });
  });

  describe('revokeRefreshToken', () => {
    it('should revoke refresh token', async () => {
      const tokenHash = createHash('sha256').update('token-to-revoke').digest('hex');

      const mockUpdate = vi.fn().mockReturnValue({
        eq: vi.fn().mockResolvedValue({
          data: { id: 'token-123' },
          error: null,
        }),
      });

      mockSupabase.from.mockReturnValue({
        update: mockUpdate,
      } as any);

      const result = await revokeRefreshToken('token-to-revoke');

      expect(result).toBe(true);
      expect(mockUpdate).toHaveBeenCalled();
    });

    it('should return false if token not found', async () => {
      const mockUpdate = vi.fn().mockReturnValue({
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Not found' },
        }),
      });

      mockSupabase.from.mockReturnValue({
        update: mockUpdate,
      } as any);

      const result = await revokeRefreshToken('non-existent-token');

      expect(result).toBe(false);
    });
  });
});
