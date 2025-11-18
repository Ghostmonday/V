/**
 * Admin Moderation Routes
 * Endpoints for reviewing flagged messages and moderation actions
 */

import { Router, Request, Response } from 'express';
import { requireAdmin, requireModerator } from '../middleware/admin-auth.js';
import { getFlaggedMessages, reviewFlaggedMessage } from '../services/message-flagging-service.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { rateLimit } from '../middleware/rate-limiter.js';
import { supabase } from '../config/db.ts';

const router = Router();

// Rate limiting: 100 requests per minute for admin endpoints
router.use(rateLimit({ max: 100, windowMs: 60 * 1000 }));

/**
 * GET /admin/moderation/flagged
 * Get flagged messages for review (admin only)
 */
router.get('/flagged', requireAdmin, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const status = (req.query.status as any) || 'pending';
    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;

    const flagged = await getFlaggedMessages(status, limit, offset);

    res.json({
      success: true,
      flagged,
      pagination: {
        limit,
        offset,
        hasMore: flagged.length === limit,
      },
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get flagged messages' });
  }
});

/**
 * POST /admin/moderation/review/:flagId
 * Review a flagged message (admin only)
 */
router.post('/review/:flagId', requireAdmin, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { flagId } = req.params;
    const { action, notes } = req.body;
    const reviewerId = req.user?.id || req.user?.userId;

    if (!reviewerId) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (!action || !['dismiss', 'warn', 'mute', 'ban', 'delete_message'].includes(action)) {
      return res.status(400).json({ error: 'Invalid action' });
    }

    const success = await reviewFlaggedMessage(flagId, reviewerId, action, notes);

    if (!success) {
      return res.status(404).json({ error: 'Flag not found' });
    }

    res.json({ success: true, action });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to review flag' });
  }
});

/**
 * GET /admin/moderation/stats
 * Get moderation statistics (admin only)
 */
router.get('/stats', requireAdmin, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { data: pending } = await supabase
      .from('flagged_messages')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending');

    const { data: reviewed } = await supabase
      .from('flagged_messages')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'reviewed');

    const { data: actionTaken } = await supabase
      .from('flagged_messages')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'action_taken');

    res.json({
      success: true,
      stats: {
        pending: pending?.length || 0,
        reviewed: reviewed?.length || 0,
        actionTaken: actionTaken?.length || 0,
      },
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get moderation stats' });
  }
});

export default router;
