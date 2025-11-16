import { Response, NextFunction } from 'express';
import { logAudit } from '../shared/logger.js';
import { AuthenticatedRequest } from '../types/auth.types.js';

export const moderateContent = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const content = req.body?.content || req.body?.prompt || '';
  if (!content) {
    return next();
  }
  
  try {
    // Input validation
    if (typeof content !== 'string') {
      return res.status(400).json({ error: 'Content must be a string' });
    }

    // Length check
    // @llm_param - Maximum content length for moderation. Prevents extremely long inputs that could abuse LLM APIs.
    if (content.length > 50000) {
      return res.status(400).json({ error: 'Content exceeds maximum length' });
    }

    // Basic moderation - check for blocked words
    // @llm_param - Blocked words list from environment. Controls content filtering before LLM processing.
    const blockedWords = process.env.BLOCKED_WORDS?.split(',').map(w => w.trim()).filter(Boolean) || [];
    const contentLower = content.toLowerCase();
    
    const hasBlockedContent = blockedWords.some(word => {
      if (!word) return false;
      // Check for whole word matches (basic)
      const regex = new RegExp(`\\b${word.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i');
      return regex.test(contentLower);
    });
    
    if (hasBlockedContent) {
      const userId = req.user?.userId || 'anonymous';
      await logAudit('content_moderated', userId, { 
        reason: 'blocked_word',
        content_length: content.length 
      });
      return res.status(400).json({ error: 'Content violates community guidelines' });
    }

    // Check for excessive repetition (spam detection)
    const words = content.split(/\s+/);
    const wordCounts: Record<string, number> = {};
    for (const word of words) {
      const normalized = word.toLowerCase();
      wordCounts[normalized] = (wordCounts[normalized] || 0) + 1;
    }
    
    const maxRepetition = Math.max(...Object.values(wordCounts));
    // @llm_param - Maximum word repetition threshold for spam detection. Flags content with excessive repetition.
    if (maxRepetition > 20 && words.length > 50) {
      const userId = req.user?.userId || 'anonymous';
      await logAudit('content_moderated', userId, { 
        reason: 'excessive_repetition',
        max_repetition: maxRepetition 
      });
      return res.status(400).json({ error: 'Content appears to be spam' });
    }
    
    next();
  } catch (error: unknown) {
    // Log moderation errors but don't block the request
    const err = error instanceof Error ? error : new Error(String(error));
    await logAudit('moderation_error', req.user?.userId || 'anonymous', { 
      error: err.message 
    });
    next(error);
  }
};

