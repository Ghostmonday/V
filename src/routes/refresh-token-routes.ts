/**
 * Refresh Token Routes
 * Handles token refresh and revocation endpoints
 */

import { Router, Request, Response } from 'express';
import { rotateRefreshToken, revokeRefreshToken, revokeAllUserTokens } from '../services/refresh-token-service.js';
import { authMiddleware } from '../middleware/auth.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { rateLimit } from '../middleware/rate-limiter.js';

const router = Router();

// Rate limiting: 10 refresh attempts per 5 minutes per IP
router.use(rateLimit({ max: 10, windowMs: 5 * 60 * 1000 }));

/**
 * POST /auth/refresh
 * Rotate refresh token and get new access token
 */
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    // VALIDATION CHECKPOINT: Validate refresh token from body or cookie
    const refreshToken = req.body.refreshToken || req.cookies?.refreshToken;

    if (!refreshToken || typeof refreshToken !== 'string') {
      return res.status(400).json({ error: 'Refresh token is required' });
    }

    const ipAddress = req.ip || req.socket.remoteAddress || undefined;
    const userAgent = req.headers['user-agent'];

    const result = await rotateRefreshToken(refreshToken, ipAddress, userAgent);

    if (!result) {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    // VALIDATION CHECKPOINT: Validate token pair structure
    if (!result.accessToken || !result.refreshToken) {
      return res.status(500).json({ error: 'Token issuance failed' });
    }

    // Set HTTP-only cookie for refresh token (more secure than returning in body)
    const isProduction = process.env.NODE_ENV === 'production';
    res.cookie('refreshToken', result.refreshToken, {
      httpOnly: true, // Not accessible via JavaScript (XSS protection)
      secure: isProduction, // Only sent over HTTPS in production
      sameSite: 'strict', // CSRF protection
      maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
      path: '/auth',
    });

    // VALIDATION CHECKPOINT: Validate response structure
    res.json({
      accessToken: result.accessToken,
      expiresAt: result.expiresAt.toISOString(),
      // Refresh token not returned in body (only in HTTP-only cookie)
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to refresh token' });
  }
});

/**
 * POST /auth/revoke
 * Revoke a specific refresh token
 */
router.post('/revoke', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken || typeof refreshToken !== 'string') {
      return res.status(400).json({ error: 'Refresh token is required' });
    }

    const success = await revokeRefreshToken(refreshToken);

    if (!success) {
      return res.status(404).json({ error: 'Token not found or already revoked' });
    }

    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to revoke token' });
  }
});

/**
 * POST /auth/revoke-all
 * Revoke all refresh tokens for authenticated user
 */
router.post('/revoke-all', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.id || req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const count = await revokeAllUserTokens(userId);

    res.json({
      success: true,
      revokedCount: count,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to revoke tokens' });
  }
});

export default router;

