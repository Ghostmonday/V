/**
 * User Authentication Routes
 * Handles Apple Sign-In and credential-based authentication endpoints
 */

import { Router, Request, Response } from 'express';
import * as authenticationService from '../services/user-authentication-service.js';
import { issueTokenPair } from '../services/refresh-token-service.js';
import { telemetryHook } from '../telemetry/index.js';
import { rateLimit } from '../middleware/rate-limiter.js';
import { bruteForceProtection, recordSuccessfulLogin, recordFailedLogin } from '../middleware/brute-force-protection.js';

const router = Router();

// SECURITY: Apply strict rate limiting to authentication endpoints
// Prevents brute force attacks - 5 attempts per 15 minutes per IP
router.use(rateLimit({ max: 5, windowMs: 15 * 60 * 1000 }));

// SECURITY: Apply brute-force protection to all auth routes
router.use(bruteForceProtection());

/**
 * POST /auth/apple
 * Verify Apple ID token and create user session
 */
router.post('/apple', async (req, res, next) => {
  try {
    telemetryHook('auth_apple_start');
    const result = await authenticationService.verifyAppleSignInToken(
      req.body.token,
      req.body.ageVerified
    );
    telemetryHook('auth_apple_end');
    res.json(result);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /auth/login
 * Authenticate with username and password (legacy - uses username)
 */
router.post('/login', async (req, res, next) => {
  try {
    telemetryHook('auth_login_start');
    const identifier = (req as any).bruteForceProtection?.identifier || req.ip || 'unknown';
    
    try {
      const result = await authenticationService.authenticateWithCredentials(
        req.body.username,
        req.body.password
      );
      
      // VALIDATION CHECKPOINT: Validate authentication successful
      if (!result || !result.jwt) {
        throw new Error('Authentication failed');
      }
      
      // Record successful login
      await recordSuccessfulLogin(identifier);
      
      telemetryHook('auth_login_end');
      res.json(result);
    } catch (authError: any) {
      // Record failed login attempt
      const attemptResult = await recordFailedLogin(identifier);
      
      if (attemptResult.locked) {
        return res.status(423).json({
          error: 'Account temporarily locked',
          message: `Too many failed login attempts. Account locked for ${15} minutes.`,
        });
      }
      
      if (attemptResult.captchaRequired) {
        return res.status(400).json({
          error: authError.message || 'Invalid username or password',
          captchaRequired: true,
          attemptsRemaining: attemptResult.attemptsRemaining,
        });
      }
      
      return res.status(401).json({
        error: authError.message || 'Invalid username or password',
        attemptsRemaining: attemptResult.attemptsRemaining,
      });
    }
  } catch (error) {
    next(error);
  }
});

/**
 * POST /auth/login-email
 * NEW: Authenticate with email and password using Supabase Auth
 * Returns access token and refresh token pair
 */
router.post('/login-email', async (req: Request, res: Response, next) => {
  try {
    telemetryHook('auth_login_email_start');
    const { email, password } = req.body;
    
    // VALIDATION CHECKPOINT: Validate email and password provided
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    
    const identifier = (req as any).bruteForceProtection?.identifier || req.ip || 'unknown';
    
    try {
      // Use new authenticate function
      const user = await authenticationService.authenticate(email, password);
      
      // VALIDATION CHECKPOINT: Validate user authenticated successfully
      if (!user || !user.id) {
        throw new Error('Authentication failed');
      }
      
      // Record successful login (clears failed attempts)
      await recordSuccessfulLogin(identifier);
      
      // Issue token pair (access + refresh tokens)
      const ipAddress = req.ip || req.socket.remoteAddress || undefined;
      const userAgent = req.headers['user-agent'];
      const tokenPair = await issueTokenPair(user.id, ipAddress, userAgent);
      
      // VALIDATION CHECKPOINT: Validate token pair issued successfully
      if (!tokenPair.accessToken || !tokenPair.refreshToken) {
        throw new Error('Token issuance failed');
      }
      
      // Set HTTP-only cookie for refresh token (more secure)
      const isProduction = process.env.NODE_ENV === 'production';
      res.cookie('refreshToken', tokenPair.refreshToken, {
        httpOnly: true, // Not accessible via JavaScript (XSS protection)
        secure: isProduction, // Only sent over HTTPS in production
        sameSite: 'strict', // CSRF protection
        maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
        path: '/auth',
      });

      // VALIDATION CHECKPOINT: Validate cookie set successfully
      telemetryHook('auth_login_email_end');
      res.json({
        accessToken: tokenPair.accessToken,
        expiresAt: tokenPair.expiresAt.toISOString(),
        // Refresh token only in HTTP-only cookie, not in response body
      });
    } catch (authError: any) {
      // Record failed login attempt
      const attemptResult = await recordFailedLogin(identifier);
      
      // VALIDATION CHECKPOINT: Validate failed attempt recorded
      if (attemptResult.locked) {
        return res.status(423).json({
          error: 'Account temporarily locked',
          message: `Too many failed login attempts. Account locked for ${15} minutes.`,
          lockedUntil: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
        });
      }
      
      if (attemptResult.captchaRequired) {
        return res.status(400).json({
          error: authError.message || 'Invalid email or password',
          captchaRequired: true,
          attemptsRemaining: attemptResult.attemptsRemaining,
        });
      }
      
      return res.status(401).json({
        error: authError.message || 'Invalid email or password',
        attemptsRemaining: attemptResult.attemptsRemaining,
      });
    }
  } catch (error) {
    next(error);
  }
});

/**
 * POST /auth/register
 * Register a new user with username and password
 */
router.post('/register', async (req, res, next) => {
  try {
    telemetryHook('auth_register_start');
    const { username, password, ageVerified } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    const result = await authenticationService.registerUser(username, password, ageVerified);
    telemetryHook('auth_register_end');
    res.json(result);
  } catch (error) {
    next(error);
  }
});

export default router;

