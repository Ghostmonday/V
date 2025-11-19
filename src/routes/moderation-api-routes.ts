/**
 * Moderation Routes
 * Phase 5.3: User-facing moderation endpoints for manual flagging
 */

import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth/supabase-auth.js';
import { flagMessage } from '../services/message-flagging-service.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { rateLimit } from '../middleware/rate-limiting/rate-limiter.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { supabase } from '../config/database-config.js';

const router = Router();

// Rate limiting: 10 flag requests per hour per user
router.use(rateLimit({ max: 10, windowMs: 60 * 60 * 1000 }));

/**
 * POST /api/moderation/flag
 * Flag a message for review (user-facing endpoint)
 * Body: { message_id, room_id, reason }
 */
router.post('/flag', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.userId || req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { message_id, room_id, reason } = req.body;

    // Validation
    if (!message_id || !room_id) {
      return res.status(400).json({ error: 'message_id and room_id are required' });
    }

    if (!reason || !['toxicity', 'spam', 'harassment', 'inappropriate', 'other'].includes(reason)) {
      return res.status(400).json({
        error: 'Invalid reason. Must be one of: toxicity, spam, harassment, inappropriate, other',
      });
    }

    // Verify message exists and user has access to room
    const { data: message, error: messageError } = await supabase
      .from('messages')
      .select('id, room_id, sender_id')
      .eq('id', message_id)
      .eq('room_id', room_id)
      .single();

    if (messageError || !message) {
      return res.status(404).json({ error: 'Message not found' });
    }

    // Check if user is member of room
    const { data: membership } = await supabase
      .from('room_memberships')
      .select('user_id')
      .eq('room_id', room_id)
      .eq('user_id', userId)
      .single();

    if (!membership) {
      return res.status(403).json({ error: 'You must be a member of this room to flag messages' });
    }

    // Prevent self-flagging
    if (message.sender_id === userId) {
      return res.status(400).json({ error: 'You cannot flag your own messages' });
    }

    // Check if already flagged by this user
    const { data: existingFlag } = await supabase
      .from('flagged_messages')
      .select('id')
      .eq('message_id', message_id)
      .eq('flagged_by', userId)
      .single();

    if (existingFlag) {
      return res.status(409).json({ error: 'You have already flagged this message' });
    }

    // Flag the message
    const flagged = await flagMessage(
      message_id,
      room_id,
      message.sender_id,
      reason,
      0, // Score not available for manual flags
      userId, // Flagged by user
      {
        manual_flag: true,
        flagged_by_user: userId,
        reason_details: req.body.reason_details || '',
      }
    );

    if (!flagged) {
      return res.status(500).json({ error: 'Failed to flag message' });
    }

    logInfo(`Message flagged manually: ${message_id} by user ${userId} for ${reason}`);

    res.json({
      success: true,
      flag_id: flagged.id,
      message: 'Message flagged successfully. It will be reviewed by moderators.',
    });
  } catch (error: any) {
    logError('Failed to flag message', error);
    res.status(500).json({ error: 'Failed to flag message' });
  }
});

/**
 * GET /api/moderation/my-flags
 * Get flags submitted by current user
 */
router.get('/my-flags', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.userId || req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;

    const { data: flags, error } = await supabase
      .from('flagged_messages')
      .select('*')
      .eq('flagged_by', userId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      throw error;
    }

    res.json({
      success: true,
      flags: flags || [],
      pagination: {
        limit,
        offset,
        hasMore: (flags || []).length === limit,
      },
    });
  } catch (error: any) {
    logError('Failed to get user flags', error);
    res.status(500).json({ error: 'Failed to get flags' });
  }
});

export default router;
