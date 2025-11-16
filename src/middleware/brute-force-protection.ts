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
import { getRedisClient } from '../config/db.js';
import { logError, logWarning, logAudit } from '../shared/logger.js';
import { validateServiceData } from './incremental-validation.js';
import { z } from 'zod';

const redis = getRedisClient();

// Configuration
const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_DURATION_SECONDS = 15 * 60; // 15 minutes
const CAPTCHA_THRESHOLD = 3; // Require CAPTCHA after 3 failures
const ATTEMPT_WINDOW_SECONDS = 15 * 60; // Track attempts in 15-minute window

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
    const windowStart = now - (ATTEMPT_WINDOW_SECONDS * 1000);
    
    let attempts: LoginAttempt;
    
    if (existing && existing.firstAttempt > windowStart) {
      // Within window - increment count
      attempts = {
        count: existing.count + 1,
        firstAttempt: existing.firstAttempt,
        lastAttempt: now,
        captchaRequired: existing.count + 1 >= CAPTCHA_THRESHOLD,
        lockedUntil: existing.count + 1 >= MAX_LOGIN_ATTEMPTS 
          ? now + (LOCKOUT_DURATION_SECONDS * 1000)
          : existing.lockedUntil,
      };
    } else {
      // New window - reset count
      attempts = {
        count: 1,
        firstAttempt: now,
        lastAttempt: now,
        captchaRequired: false,
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
export async function isAccountLocked(identifier: string): Promise<{ locked: boolean; lockedUntil?: Date; reason?: string }> {
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
 * Verify CAPTCHA token (simple validation - integrate with actual CAPTCHA service)
 */
async function verifyCaptchaToken(token: string, challenge?: string): Promise<boolean> {
  // VALIDATION CHECKPOINT: Validate CAPTCHA token format
  try {
    const validated = validateServiceData(
      { token, challenge },
      captchaTokenSchema,
      'verifyCaptchaToken'
    );
    
    // TODO: Integrate with actual CAPTCHA service (reCAPTCHA, hCaptcha, etc.)
    // For now, validate token exists and is not empty
    if (!validated.token || validated.token.length === 0) {
      return false;
    }
    
    // Placeholder: In production, verify token with CAPTCHA service
    // Example: await fetch('https://www.google.com/recaptcha/api/siteverify', { ... })
    
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
        return res.status(423).json({ // 423 = Locked
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
export async function recordFailedLogin(identifier: string): Promise<{ locked: boolean; captchaRequired: boolean; attemptsRemaining: number }> {
  const attempts = await recordFailedAttempt(identifier);
  
  return {
    locked: !!attempts.lockedUntil && attempts.lockedUntil > Date.now(),
    captchaRequired: attempts.captchaRequired,
    attemptsRemaining: Math.max(0, MAX_LOGIN_ATTEMPTS - attempts.count),
  };
}

