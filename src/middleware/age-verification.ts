/**
 * Age Verification Middleware
 * Checks if user has verified they are 18+ before allowing room-related actions
 * Must be used after authMiddleware
 */

import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types/auth.types.js';
import { findOne } from '../../shared/supabase-helpers.js';
import { logError } from '../../shared/logger.js';

export const ageVerificationMiddleware = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  const userId = req.user?.userId;
  
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    // Fetch user's age_verified status
    const user = await findOne<{ age_verified: boolean }>('users', { id: userId });
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (!user.age_verified) {
      return res.status(403).json({ 
        error: 'Age verification required',
        message: 'You must verify that you are 18+ to create or join rooms'
      });
    }

    next();
  } catch (error) {
    logError('Age verification middleware error', error instanceof Error ? error : new Error(String(error)));
    res.status(500).json({ error: 'Failed to verify age status' });
  }
};

