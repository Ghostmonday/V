/**
 * Supabase JWT Auth Middleware
 * Validates Supabase-issued JWTs for protected routes
 * Backend relies solely on Supabase-issued JWTs from iOS client
 */

import { Request, Response, NextFunction } from 'express';
import { createClient } from '@supabase/supabase-js';
import * as Sentry from '@sentry/node';
import { AuthenticatedRequest, AuthenticatedUser } from '../../types/auth-types.js';

// Initialize Supabase client for token verification
const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || '';

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase credentials. Set SUPABASE_URL and SUPABASE_ANON_KEY');
}

const supabase = supabaseUrl && supabaseAnonKey ? createClient(supabaseUrl, supabaseAnonKey) : null;

// Type definitions
interface User {
  id: string;
  email?: string;
  user_metadata?: Record<string, any>;
}

declare global {
  namespace Express {
    interface Request {
      user?: User | AuthenticatedUser;
    }
  }
}

/**
 * Supabase JWT auth middleware
 * - Expects Authorization: Bearer <supabase-jwt>
 * - Validates token with Supabase
 * - Sets req.user on success
 * - OPTIONAL: if no header, calls next() (routes must enforce when required)
 */
export const supabaseAuthMiddleware = async (
  req: AuthenticatedRequest | Request,
  res: Response,
  next: NextFunction
) => {
  const header = req.headers.authorization;

  // Optional auth - if no header, allow request through
  // Routes must check req.user if auth is required
  if (!header) {
    return next();
  }

  const token = header.split(' ')[1];
  if (!token) {
    return next(); // Optional auth - allow through
  }

  if (!supabase) {
    Sentry.captureMessage('Supabase client not initialized', 'error');
    return res.status(500).json({ error: 'Server configuration error' });
  }

  try {
    // Verify token with Supabase
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      Sentry.addBreadcrumb({
        message: 'Supabase JWT verification failed',
        level: 'warning',
        data: { error: authError?.message || 'User not found' },
      });
      return res.status(401).json({ error: 'Invalid token' });
    }

    // Set user on request
    req.user = {
      id: user.id,
      email: user.email,
      ...(user.user_metadata && { user_metadata: user.user_metadata }),
    } as AuthenticatedUser;

    next();
  } catch (err) {
    // Token verification error
    Sentry.addBreadcrumb({
      message: 'Supabase JWT verification error',
      level: 'error',
      data: { error: err instanceof Error ? err.message : String(err) },
    });
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Alias export for backward compatibility
export const authMiddleware = supabaseAuthMiddleware;

// Default export for compatibility
export default supabaseAuthMiddleware;
