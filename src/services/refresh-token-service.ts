/**
 * Refresh Token Service
 * Implements secure token rotation with server-side invalidation
 *
 * Features:
 * - Token family tracking for rotation detection
 * - Automatic invalidation of reused tokens
 * - Secure token hashing (SHA256)
 * - Audit logging
 */

import crypto from 'crypto';
import { supabase } from '../config/db.ts';
import { logError, logInfo, logAudit } from '../shared/logger.js';
import { issueToken } from './user-authentication-service.js';

const REFRESH_TOKEN_EXPIRY_DAYS = 30;
const ACCESS_TOKEN_EXPIRY_MINUTES = 15;

interface RefreshTokenRecord {
  id: string;
  user_id: string;
  token_hash: string;
  family_id: string;
  expires_at: string;
  created_at: string;
  last_used_at: string | null;
  revoked_at: string | null;
}

/**
 * Generate a secure refresh token
 */
function generateRefreshToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

/**
 * Hash a refresh token for storage
 */
function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

/**
 * Generate a new token family ID
 */
function generateFamilyId(): string {
  return crypto.randomUUID();
}

/**
 * Issue new refresh token and access token pair
 */
export async function issueTokenPair(
  userId: string,
  ipAddress?: string,
  userAgent?: string
): Promise<{ accessToken: string; refreshToken: string; expiresAt: Date }> {
  try {
    const refreshToken = generateRefreshToken();
    const tokenHash = hashToken(refreshToken);
    const familyId = generateFamilyId();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + REFRESH_TOKEN_EXPIRY_DAYS);

    // Store refresh token
    const { error } = await supabase.from('refresh_tokens').insert({
      user_id: userId,
      token_hash: tokenHash,
      family_id: familyId,
      expires_at: expiresAt.toISOString(),
      ip_address: ipAddress,
      user_agent: userAgent,
    });

    if (error) {
      throw error;
    }

    // Generate short-lived access token
    const accessToken = issueToken({ id: userId });

    // Log successful token issuance
    await logAuthEvent(userId, 'token_issued', true, ipAddress, userAgent);

    return {
      accessToken,
      refreshToken,
      expiresAt,
    };
  } catch (error: any) {
    logError('Failed to issue token pair', error);
    await logAuthEvent(userId, 'token_issue_failed', false, ipAddress, userAgent, error.message);
    throw error;
  }
}

/**
 * Invalidate entire token family (security measure for reuse attacks)
 */
async function invalidateTokenFamily(
  familyId: string,
  reason: string = 'Security violation'
): Promise<number> {
  try {
    const { data, error } = await supabase
      .from('refresh_tokens')
      .update({ revoked_at: new Date().toISOString() })
      .eq('family_id', familyId)
      .is('revoked_at', null)
      .select('id');

    if (error) {
      logError('Failed to invalidate token family', error);
      return 0;
    }

    // Log family invalidation for each affected token
    if (data && data.length > 0) {
      const userIds = new Set<string>();
      for (const token of data) {
        const { data: tokenData } = await supabase
          .from('refresh_tokens')
          .select('user_id')
          .eq('id', token.id)
          .single();
        if (tokenData?.user_id) {
          userIds.add(tokenData.user_id);
        }
      }

      // Log audit event for each affected user
      for (const userId of userIds) {
        await logAuthEvent(userId, 'token_family_invalidated', false, undefined, undefined, reason);
      }
    }

    return data?.length || 0;
  } catch (error: any) {
    logError('Error invalidating token family', error);
    return 0;
  }
}

/**
 * Rotate refresh token (issue new pair, invalidate old)
 * Implements token rotation: if token is reused, invalidate entire family
 */
export async function rotateRefreshToken(
  refreshToken: string,
  ipAddress?: string,
  userAgent?: string
): Promise<{ accessToken: string; refreshToken: string; expiresAt: Date } | null> {
  try {
    const tokenHash = hashToken(refreshToken);

    // Find token record
    const { data: tokenRecord, error: findError } = (await supabase
      .from('refresh_tokens')
      .select('*')
      .eq('token_hash', tokenHash)
      .is('revoked_at', null)
      .single()) as { data: RefreshTokenRecord | null; error: any };

    if (findError || !tokenRecord) {
      await logAuthEvent(
        null,
        'token_refresh_failed',
        false,
        ipAddress,
        userAgent,
        'Invalid token'
      );
      return null;
    }

    // Check if token is expired
    if (new Date(tokenRecord.expires_at) < new Date()) {
      await logAuthEvent(
        tokenRecord.user_id,
        'token_refresh_failed',
        false,
        ipAddress,
        userAgent,
        'Token expired'
      );
      return null;
    }

    // Check if token was already used (reuse detection)
    if (tokenRecord.last_used_at) {
      // Token reuse detected - invalidate entire family (security measure)
      const invalidatedCount = await invalidateTokenFamily(
        tokenRecord.family_id,
        `Token reuse detected from IP ${ipAddress || 'unknown'}`
      );

      await logAuthEvent(
        tokenRecord.user_id,
        'token_reuse_detected',
        false,
        ipAddress,
        userAgent,
        `Token reuse detected - ${invalidatedCount} tokens in family invalidated`
      );
      return null;
    }

    // Mark token as used
    await supabase
      .from('refresh_tokens')
      .update({ last_used_at: new Date().toISOString() })
      .eq('id', tokenRecord.id);

    // Revoke old token
    await supabase
      .from('refresh_tokens')
      .update({ revoked_at: new Date().toISOString() })
      .eq('id', tokenRecord.id);

    // Issue new token pair with same family ID
    const newRefreshToken = generateRefreshToken();
    const newTokenHash = hashToken(newRefreshToken);
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + REFRESH_TOKEN_EXPIRY_DAYS);

    await supabase.from('refresh_tokens').insert({
      user_id: tokenRecord.user_id,
      token_hash: newTokenHash,
      family_id: tokenRecord.family_id, // Same family
      expires_at: expiresAt.toISOString(),
      ip_address: ipAddress,
      user_agent: userAgent,
    });

    // Generate new access token
    const accessToken = issueToken({ id: tokenRecord.user_id });

    await logAuthEvent(tokenRecord.user_id, 'token_refreshed', true, ipAddress, userAgent);

    return {
      accessToken,
      refreshToken: newRefreshToken,
      expiresAt,
    };
  } catch (error: any) {
    logError('Failed to rotate refresh token', error);
    await logAuthEvent(null, 'token_refresh_failed', false, ipAddress, userAgent, error.message);
    return null;
  }
}

/**
 * Revoke a refresh token
 */
export async function revokeRefreshToken(refreshToken: string): Promise<boolean> {
  try {
    const tokenHash = hashToken(refreshToken);

    const { data, error } = await supabase
      .from('refresh_tokens')
      .update({ revoked_at: new Date().toISOString() })
      .eq('token_hash', tokenHash)
      .is('revoked_at', null)
      .select('user_id')
      .single();

    if (error || !data) {
      return false;
    }

    await logAuthEvent(data.user_id, 'token_revoked', true);
    return true;
  } catch (error: any) {
    logError('Failed to revoke refresh token', error);
    return false;
  }
}

/**
 * Revoke all refresh tokens for a user
 */
export async function revokeAllUserTokens(userId: string): Promise<number> {
  try {
    const { data, error } = await supabase
      .from('refresh_tokens')
      .update({ revoked_at: new Date().toISOString() })
      .eq('user_id', userId)
      .is('revoked_at', null)
      .select('id');

    if (error) {
      throw error;
    }

    await logAuthEvent(userId, 'all_tokens_revoked', true);
    return data?.length || 0;
  } catch (error: any) {
    logError('Failed to revoke all user tokens', error);
    return 0;
  }
}

/**
 * Log authentication event to audit log
 */
async function logAuthEvent(
  userId: string | null,
  eventType:
    | 'login'
    | 'logout'
    | 'login_failed'
    | 'token_issued'
    | 'token_refreshed'
    | 'token_revoked'
    | 'token_reuse_detected'
    | 'token_issue_failed'
    | 'token_refresh_failed'
    | 'all_tokens_revoked'
    | 'token_family_invalidated',
  success: boolean,
  ipAddress?: string,
  userAgent?: string,
  failureReason?: string,
  metadata?: Record<string, any>
): Promise<void> {
  try {
    await supabase.from('auth_audit_log').insert({
      user_id: userId,
      event_type: eventType,
      ip_address: ipAddress,
      user_agent: userAgent,
      success,
      failure_reason: failureReason,
      metadata: metadata || {},
    });
  } catch (error: any) {
    // Non-critical: log but don't fail
    logError('Failed to log auth event', error);
  }
}

/**
 * Get access token expiry time
 */
export function getAccessTokenExpiry(): Date {
  const expiresAt = new Date();
  expiresAt.setMinutes(expiresAt.getMinutes() + ACCESS_TOKEN_EXPIRY_MINUTES);
  return expiresAt;
}
