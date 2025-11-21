/**
 * Authentication types
 * Proper types for authenticated requests
 */

import { Request } from 'express';

export interface AuthenticatedUser {
  userId: string;
  id: string; // Add id property for compatibility
  iat?: number;
  exp?: number;
}

export interface AuthenticatedRequest extends Request {
  user: AuthenticatedUser;
  file?: Express.Multer.File;
}
