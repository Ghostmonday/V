/**
 * VIBES-specific authentication middleware
 * Additional checks for VIBES features
 */

import { Request, Response, NextFunction } from 'express';
import { vibesConfig } from '../config/vibes.config.js';
import { logError } from '../shared/logger.js';

/**
 * Check if card generation is enabled
 */
export function requireCardGeneration(req: Request, res: Response, next: NextFunction): void {
  if (!vibesConfig.cardGenerationEnabled) {
    res.status(503).json({ error: 'Card generation is currently disabled' });
    return;
  }
  next();
}

/**
 * Validate conversation access
 */
export async function validateConversationAccess(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const conversationId = req.params.id || req.body.conversation_id;
    const userId = (req as any).user?.id;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    // TODO: Check if user is participant in conversation
    // For now, allow through
    next();
  } catch (error) {
    logError('Failed to validate conversation access', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}
