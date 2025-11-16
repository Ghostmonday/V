/**
 * JWT auth middleware
 * - expects Authorization: Bearer <token>
 * - sets req.user on success
 * - OPTIONAL: if no header, calls next() (routes must enforce when required)
 * - Keeps all existing features: vault lookup, Sentry, caching
 */

import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { getJwtSecret } from '../services/api-keys-service.js';
import { AuthenticatedRequest, AuthenticatedUser } from '../types/auth.types.js';
import * as Sentry from '@sentry/node';

// Cache JWT secret to avoid repeated DB calls
let cachedJwtSecret: string | null = null;
let secretCacheTime = 0;
const SECRET_CACHE_TTL = 5 * 60 * 1000; // 5 minutes

async function getCachedJwtSecret(): Promise<string> {
  const now = Date.now();
  if (cachedJwtSecret && (now - secretCacheTime) < SECRET_CACHE_TTL) {
    return cachedJwtSecret;
  }
  
  cachedJwtSecret = await getJwtSecret();
  secretCacheTime = now;
  return cachedJwtSecret;
}

// Type definitions for optional auth
interface User {
  id: string;
  tier?: string;
  handle?: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: User | AuthenticatedUser;
    }
  }
}

// Named export (existing usage)
export const authMiddleware = async (req: AuthenticatedRequest | Request, res: Response, next: NextFunction) => {
  const header = req.headers.authorization;
  
  // NEW: Optional auth - if no header, allow request through
  if (!header) {
    return next(); // Routes must check req.user if auth is required
  }
  
  const token = header.split(' ')[1];
  if (!token) {
    return next(); // Optional auth - allow through
  }
  
  try {
    // Try vault first (existing behavior)
    let jwtSecret: string;
    try {
      jwtSecret = await getCachedJwtSecret();
    } catch (vaultError) {
      // Fallback to env var if vault fails
      jwtSecret = process.env.JWT_SECRET as string;
      if (!jwtSecret) {
        Sentry.captureMessage('JWT secret not found in vault or env', 'error');
        return res.status(500).json({ error: 'Server configuration error' });
      }
    }
    
    if (!jwtSecret) {
      Sentry.captureMessage('JWT secret not found in vault', 'error');
      return res.status(500).json({ error: 'Server configuration error' });
    }
    
    const decoded = jwt.verify(token, jwtSecret) as User | AuthenticatedUser | { id?: string; userId?: string; tier?: string; handle?: string };
    
    // Normalize user object - support both 'id' and 'userId' formats
    if ('id' in decoded && decoded.id) {
      // New format: { id, tier?, handle? }
      req.user = decoded as User;
    } else if ('userId' in decoded && decoded.userId) {
      // Legacy format: { userId }
      req.user = decoded as AuthenticatedUser;
    } else {
      // Fallback: try to extract id from either format
      req.user = decoded as AuthenticatedUser | User;
    }
    
    next();
  } catch (err) {
    // JWT expired/invalid - return 401
    Sentry.addBreadcrumb({
      message: 'JWT verification failed',
      level: 'warning',
      data: { error: err instanceof Error ? err.message : String(err) }
    });
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Default export (for new usage)
export default authMiddleware;
