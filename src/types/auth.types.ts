/**
 * Authentication types
 * Proper types for authenticated requests
 */

import { Request } from 'express';

export interface AuthenticatedUser {
  userId: string;
  iat?: number;
  exp?: number;
}

export interface AuthenticatedRequest extends Request {
  user: AuthenticatedUser;
}

