/**
 * Brute-force Protection Middleware
 * Tracks login attempts and implements account lockout
 *
 * Features:
 * - Login attempt tracking per IP and user
 * - Account lockout after 5 failures
 * - CAPTCHA requirement after 3 failures
 * - Automatic unlock after lockout period
 */

import { Request, Response, NextFunction } from 'express';
import { getRedisClient } from '../../config/database-config.js';
import { logError, logWarning, logAudit } from '../../shared/logger-shared.js';
import { validateServiceData } from '../validation/incremental-validation-middleware.js';
import { z } from 'zod/v3';

const redis = getRedisClient();

// Configuration
const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_DURATION_SECONDS = 15 * 60; // Base lockout duration: 15 minutes
const CAPTCHA_THRESHOLD = 3; // Require CAPTCHA after 3 failures
const ATTEMPT_WINDOW_SECONDS = 60; // Track attempts in 60-second window (5/min per IP)

// Validation schema
const captchaTokenSchema = z.object({
  token: z.string().min(1),
  challenge: z.string().optional(),
});

interface LoginAttempt {
  count: number;
  firstAttempt: number;
  lastAttempt: number;
  lockedUntil?: number;
  captchaRequired: boolean;
  lockoutCount?: number; // Number of times the user/IP has been locked
}

/**
 * Get login attempt record for identifier (IP or user ID)
 */
async function getLoginAttempts(identifier: string): Promise<LoginAttempt | null> {
  try {
    if (!redis) return null;

    const key = `login_attempts:${identifier}`;
    const data = await redis.get(key);

    if (!data) return null;

    return JSON.parse(data) as LoginAttempt;
  } catch (error: any) {
    logError('Failed to get login attempts', error);
    return null;
  }
}

/**
 * Record a failed login attempt
 */
async function recordFailedAttempt(identifier: string): Promise<LoginAttempt> {
  try {
    if (!redis) {
      // Fallback: return mock attempt if Redis unavailable
      return {
        count: 1,
        firstAttempt: Date.now(),
        lastAttempt: Date.now(),
        captchaRequired: false,
      };
    }

    const key = `login_attempts:${identifier}`;
    const existing = await getLoginAttempts(identifier);

    const now = Date.now();
    const windowStart = now - ATTEMPT_WINDOW_SECONDS * 1000;

    let attempts: LoginAttempt;

    const existingLockoutCount = existing?.lockoutCount ?? 0;

    if (existing && existing.firstAttempt > windowStart) {
      // Within window - increment count
      const nextCount = existing.count + 1;
      let lockedUntil = existing.lockedUntil;
      let lockoutCount = existingLockoutCount;

      if (nextCount >= MAX_LOGIN_ATTEMPTS) {
        // Exponential backoff for lockouts:
        // 1st lockout: 15 minutes, then 30, 60, cap at 120 minutes
        const nextLockoutCount = existingLockoutCount + 1;
        const multiplier = Math.min(2 ** (nextLockoutCount - 1), 8); // 1,2,4,8
        const lockoutDurationMs = LOCKOUT_DURATION_SECONDS * 1000 * multiplier;
        lockedUntil = now + lockoutDurationMs;
        lockoutCount = nextLockoutCount;
      }

      attempts = {
        count: nextCount,
        firstAttempt: existing.firstAttempt,
        lastAttempt: now,
        captchaRequired: nextCount >= CAPTCHA_THRESHOLD,
        lockedUntil,
        lockoutCount,
      };
    } else {
      // New window - reset count but carry over historical lockout count
      attempts = {
        count: 1,
        firstAttempt: now,
        lastAttempt: now,
        captchaRequired: false,
        lockoutCount: existingLockoutCount,
      };
    }

    // Store with TTL (expires after lockout duration + window)
    const ttl = attempts.lockedUntil
      ? Math.ceil((attempts.lockedUntil - now) / 1000) + ATTEMPT_WINDOW_SECONDS
      : ATTEMPT_WINDOW_SECONDS;

    await redis.setex(key, ttl, JSON.stringify(attempts));

    // Log audit event
    await logAudit('login_attempt_failed', identifier, {
      attemptCount: attempts.count,
      locked: !!attempts.lockedUntil,
      captchaRequired: attempts.captchaRequired,
    });

    return attempts;
  } catch (error: any) {
    logError('Failed to record failed attempt', error);
    // Fail open - return mock attempt
    return {
      count: 1,
      firstAttempt: Date.now(),
      lastAttempt: Date.now(),
      captchaRequired: false,
    };
  }
}

/**
 * Clear login attempts on successful login
 */
async function clearLoginAttempts(identifier: string): Promise<void> {
  try {
    if (!redis) return;

    const key = `login_attempts:${identifier}`;
    await redis.del(key);

    await logAudit('login_attempts_cleared', identifier, {});
  } catch (error: any) {
    logError('Failed to clear login attempts', error);
  }
}

/**
 * Check if account is locked
 */
export async function isAccountLocked(
  identifier: string
): Promise<{ locked: boolean; lockedUntil?: Date; reason?: string }> {
  try {
    const attempts = await getLoginAttempts(identifier);

    if (!attempts) {
      return { locked: false };
    }

    // VALIDATION CHECKPOINT: Validate lockout duration
    if (attempts.lockedUntil && attempts.lockedUntil > Date.now()) {
      return {
        locked: true,
        lockedUntil: new Date(attempts.lockedUntil),
        reason: `Account locked due to ${attempts.count} failed login attempts. Try again after ${new Date(attempts.lockedUntil).toISOString()}`,
      };
    }

    // Lock expired - clear it
    if (attempts.lockedUntil && attempts.lockedUntil <= Date.now()) {
      await clearLoginAttempts(identifier);
      return { locked: false };
    }

    return { locked: false };
  } catch (error: any) {
    logError('Failed to check account lock status', error);
    // Fail open - don't lock on error
    return { locked: false };
  }
}

/**
 * Check if CAPTCHA is required
 */
export async function isCaptchaRequired(identifier: string): Promise<boolean> {
  try {
    const attempts = await getLoginAttempts(identifier);
    return attempts?.captchaRequired || false;
  } catch (error: any) {
    logError('Failed to check CAPTCHA requirement', error);
    return false;
  }
}

/**
 * Verify CAPTCHA token with reCAPTCHA v3
 */
async function verifyCaptchaToken(token: string, challenge?: string): Promise<boolean> {
  // VALIDATION CHECKPOINT: Validate CAPTCHA token format
  try {
    const validated = validateServiceData(
      { token, challenge },
      captchaTokenSchema,
      'verifyCaptchaToken'
    );

    if (!validated.token || validated.token.length === 0) {
      return false;
    }

    // Get reCAPTCHA secret key from environment
    const recaptchaSecretKey = process.env.RECAPTCHA_SECRET_KEY;

    if (!recaptchaSecretKey) {
      // If no secret key configured, log warning but allow through in development
      if (process.env.NODE_ENV === 'development') {
        logWarning('reCAPTCHA secret key not configured - allowing in development');
        return true;
      }
      logError('reCAPTCHA secret key not configured in production');
      return false;
    }

    // Verify token with Google reCAPTCHA API
    const verifyUrl = 'https://www.google.com/recaptcha/api/siteverify';
    const response = await fetch(verifyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        secret: recaptchaSecretKey,
        response: validated.token,
      }),
    });

    if (!response.ok) {
      logError('reCAPTCHA verification request failed', { status: response.status });
      return false;
    }

    const data = (await response.json()) as {
      success: boolean;
      score?: number;
      challenge_ts?: string;
      hostname?: string;
    };

    // VALIDATION CHECKPOINT: Validate reCAPTCHA response
    if (!data.success) {
      logWarning('reCAPTCHA verification failed', { data });
      return false;
    }

    // For reCAPTCHA v3, check score (0.0 to 1.0, higher is better)
    // Require score >= 0.5 for login attempts
    if (data.score !== undefined && data.score < 0.5) {
      logWarning('reCAPTCHA score too low', { score: data.score });
      return false;
    }

    return true;
  } catch (error: any) {
    logError('CAPTCHA verification failed', error);
    return false;
  }
}

/**
 * Middleware to check brute-force protection before authentication
 */
export function bruteForceProtection() {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Get identifier (IP address or user ID if available)
      const identifier = (req as any).user?.id || req.ip || req.socket.remoteAddress || 'unknown';

      // VALIDATION CHECKPOINT: Validate identifier format
      if (!identifier || identifier === 'unknown') {
        logWarning('Could not determine identifier for brute-force protection', { ip: req.ip });
      }

      // Check if account is locked
      const lockStatus = await isAccountLocked(identifier);

      if (lockStatus.locked) {
        // VALIDATION CHECKPOINT: Validate lockout response
        return res.status(423).json({
          // 423 = Locked
          error: 'Account temporarily locked',
          reason: lockStatus.reason,
          lockedUntil: lockStatus.lockedUntil?.toISOString(),
        });
      }

      // Check if CAPTCHA is required
      const captchaRequired = await isCaptchaRequired(identifier);

      if (captchaRequired) {
        // VALIDATION CHECKPOINT: Validate CAPTCHA token if required
        const captchaToken = req.body.captchaToken || req.headers['x-captcha-token'];

        if (!captchaToken) {
          return res.status(400).json({
            error: 'CAPTCHA required',
            message: 'Please complete the CAPTCHA challenge',
            captchaRequired: true,
          });
        }

        // Verify CAPTCHA token
        const captchaValid = await verifyCaptchaToken(captchaToken);

        if (!captchaValid) {
          // Record failed attempt (invalid CAPTCHA)
          await recordFailedAttempt(identifier);
          return res.status(400).json({
            error: 'Invalid CAPTCHA',
            message: 'CAPTCHA verification failed. Please try again.',
          });
        }
      }

      // Attach attempt tracking to request for use in auth route
      (req as any).bruteForceProtection = {
        identifier,
        recordFailedAttempt: () => recordFailedAttempt(identifier),
        clearAttempts: () => clearLoginAttempts(identifier),
      };

      next();
    } catch (error: any) {
      logError('Brute-force protection middleware error', error);
      // Fail open - allow request through on error
      next();
    }
  };
}

/**
 * Record successful login (call this after successful authentication)
 */
export async function recordSuccessfulLogin(identifier: string): Promise<void> {
  await clearLoginAttempts(identifier);
  await logAudit('login_successful', identifier, {});
}

/**
 * Record failed login (call this after failed authentication)
 */
export async function recordFailedLogin(
  identifier: string
): Promise<{ locked: boolean; captchaRequired: boolean; attemptsRemaining: number }> {
  const attempts = await recordFailedAttempt(identifier);

  return {
    locked: !!attempts.lockedUntil && attempts.lockedUntil > Date.now(),
    captchaRequired: attempts.captchaRequired,
    attemptsRemaining: Math.max(0, MAX_LOGIN_ATTEMPTS - attempts.count),
  };
}
