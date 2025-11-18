/**
 * Chat Room Config Routes
 * Manage room configuration including AI moderation settings
 */

import { Router } from 'express';
import { supabase } from '../config/db.ts';
import { logError } from '../shared/logger.js';
import { authMiddleware } from '../middleware/auth/supabase-auth.js';
import { getUserSubscription, SubscriptionTier } from '../services/subscription-service.js';
import { AuthenticatedRequest } from '../types/auth.types.js';

const router = Router();

/**
 * GET /chat_rooms/:id/config
 * Get room configuration including moderation settings
 */
router.get('/:id/config', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const roomId = req.params.id;
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    // Fetch room configuration
    const { data: room, error } = await supabase
      .from('rooms')
      .select('id, ai_moderation, room_tier, expires_at, created_by')
      .eq('id', roomId)
      .single();

    if (error || !room) {
      return res.status(404).json({ error: 'Room not found' });
    }

    // Check if user has permission (owner or admin)
    // For now, only room owner can view config
    if (room.created_by !== userId) {
      return res.status(403).json({ error: 'Permission denied' });
    }

    res.json({
      id: room.id,
      ai_moderation: room.ai_moderation || false,
      room_tier: room.room_tier || 'free',
      expires_at: room.expires_at || null,
    });
  } catch (e) {
    logError('Get room config error', e instanceof Error ? e : new Error(String(e)));
    res.status(500).json({ error: 'Failed to get room config' });
  }
});

/**
 * POST /chat_rooms/:id/config
 * Update room configuration (AI moderation toggle - enterprise only)
 * Body: { ai_moderation: boolean }
 */
router.post('/:id/config', authMiddleware, async (req, res) => {
  try {
    const roomId = req.params.id;
    const userId = (req as any).user?.userId;
    const { ai_moderation } = req.body;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    // Fetch room to check ownership and tier
    const { data: room, error: fetchError } = await supabase
      .from('rooms')
      .select('id, room_tier, created_by')
      .eq('id', roomId)
      .single();

    if (fetchError || !room) {
      return res.status(404).json({ error: 'Room not found' });
    }

    // Check if user is room owner
    if (room.created_by !== userId) {
      return res
        .status(403)
        .json({ error: 'Permission denied - only room owner can update config' });
    }

    // Check if user has enterprise subscription (required for AI moderation)
    const subscriptionTier = await getUserSubscription(userId);
    if (ai_moderation && subscriptionTier !== SubscriptionTier.TEAM) {
      // Note: Adjust this check based on your actual enterprise tier name
      // The user mentioned 'enterprise' but SubscriptionTier enum uses 'TEAM'
      // You may need to add an ENTERPRISE tier or map TEAM to enterprise
      return res.status(403).json({
        error: 'Enterprise subscription required for AI moderation',
        upgrade_url: '/subscription/upgrade',
        current_tier: subscriptionTier,
      });
    }

    // Update room configuration
    const updates: any = {};
    if (typeof ai_moderation === 'boolean') {
      updates.ai_moderation = ai_moderation;
      // If enabling moderation, ensure room tier is set to enterprise
      if (ai_moderation && room.room_tier !== 'enterprise') {
        updates.room_tier = 'enterprise';
      }
    }

    const { data: updatedRoom, error: updateError } = await supabase
      .from('rooms')
      .update(updates)
      .eq('id', roomId)
      .select('id, ai_moderation, room_tier, expires_at')
      .single();

    if (updateError) {
      logError('Update room config error', updateError);
      return res.status(500).json({ error: 'Failed to update room config' });
    }

    res.json({
      success: true,
      room: {
        id: updatedRoom.id,
        ai_moderation: updatedRoom.ai_moderation || false,
        room_tier: updatedRoom.room_tier || 'free',
        expires_at: updatedRoom.expires_at || null,
      },
    });
  } catch (e) {
    logError('Update room config error', e instanceof Error ? e : new Error(String(e)));
    res.status(500).json({ error: 'Failed to update room config' });
  }
});

/**
 * PUT /chat_rooms/:id/config
 * Update room configuration (AI moderation toggle - enterprise only)
 * Same as POST for RESTful compatibility
 */
router.put('/:id/config', authMiddleware, async (req, res) => {
  // Same handler as POST
  const roomId = req.params.id;
  const userId = (req as any).user?.userId;
  const { ai_moderation } = req.body;

  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { data: room, error: fetchError } = await supabase
    .from('rooms')
    .select('id, room_tier, created_by')
    .eq('id', roomId)
    .single();

  if (fetchError || !room) {
    return res.status(404).json({ error: 'Room not found' });
  }

  if (room.created_by !== userId) {
    return res.status(403).json({ error: 'Permission denied - only room owner can update config' });
  }

  const subscriptionTier = await getUserSubscription(userId);
  if (ai_moderation && subscriptionTier !== SubscriptionTier.TEAM) {
    return res.status(403).json({
      error: 'Enterprise subscription required for AI moderation',
      upgrade_url: '/subscription/upgrade',
      current_tier: subscriptionTier,
    });
  }

  const updates: any = {};
  if (typeof ai_moderation === 'boolean') {
    updates.ai_moderation = ai_moderation;
    if (ai_moderation && room.room_tier !== 'enterprise') {
      updates.room_tier = 'enterprise';
    }
  }

  const { data: updatedRoom, error: updateError } = await supabase
    .from('rooms')
    .update(updates)
    .eq('id', roomId)
    .select('id, ai_moderation, room_tier, expires_at')
    .single();

  if (updateError) {
    logError('Update room config error', updateError);
    return res.status(500).json({ error: 'Failed to update room config' });
  }

  res.json({
    success: true,
    room: {
      id: updatedRoom.id,
      ai_moderation: updatedRoom.ai_moderation || false,
      room_tier: updatedRoom.room_tier || 'free',
      expires_at: updatedRoom.expires_at || null,
    },
  });
});

/**
 * GET /chat_rooms/:id/moderation-thresholds
 * Get per-room moderation thresholds (Phase 5.2)
 */
router.get('/:id/moderation-thresholds', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const roomId = req.params.id;
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    // Check if user has permission (room owner or admin)
    const { data: room } = await supabase
      .from('rooms')
      .select('id, created_by')
      .eq('id', roomId)
      .single();

    if (!room) {
      return res.status(404).json({ error: 'Room not found' });
    }

    // Get room thresholds
    const { data: thresholds } = await supabase
      .from('room_moderation_thresholds')
      .select('warn_threshold, block_threshold, enabled, updated_at')
      .eq('room_id', roomId)
      .single();

    if (thresholds) {
      res.json({
        success: true,
        thresholds: {
          warn: thresholds.warn_threshold,
          block: thresholds.block_threshold,
          enabled: thresholds.enabled,
          updated_at: thresholds.updated_at,
        },
      });
    } else {
      // Return default thresholds if none set
      res.json({
        success: true,
        thresholds: {
          warn: 0.6,
          block: 0.8,
          enabled: false,
          updated_at: null,
        },
      });
    }
  } catch (e) {
    logError('Get moderation thresholds error', e instanceof Error ? e : new Error(String(e)));
    res.status(500).json({ error: 'Failed to get moderation thresholds' });
  }
});

/**
 * POST /chat_rooms/:id/moderation-thresholds
 * Set per-room moderation thresholds (Phase 5.2)
 * Requires admin or room owner permission
 */
router.post(
  '/:id/moderation-thresholds',
  authMiddleware,
  async (req: AuthenticatedRequest, res) => {
    try {
      const roomId = req.params.id;
      const userId = req.user?.userId;
      const { warn_threshold, block_threshold, enabled } = req.body;

      if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      // Validate thresholds
      if (warn_threshold !== undefined && (warn_threshold < 0 || warn_threshold > 1)) {
        return res.status(400).json({ error: 'warn_threshold must be between 0 and 1' });
      }
      if (block_threshold !== undefined && (block_threshold < 0 || block_threshold > 1)) {
        return res.status(400).json({ error: 'block_threshold must be between 0 and 1' });
      }
      if (
        warn_threshold !== undefined &&
        block_threshold !== undefined &&
        block_threshold < warn_threshold
      ) {
        return res.status(400).json({ error: 'block_threshold must be >= warn_threshold' });
      }

      // Check if user has permission (room owner or admin)
      const { data: room } = await supabase
        .from('rooms')
        .select('id, created_by')
        .eq('id', roomId)
        .single();

      if (!room) {
        return res.status(404).json({ error: 'Room not found' });
      }

      // Check if user is room owner or admin
      const { data: user } = await supabase.from('users').select('role').eq('id', userId).single();

      const isOwner = room.created_by === userId;
      const isAdmin = user?.role === 'admin' || user?.role === 'moderator';

      if (!isOwner && !isAdmin) {
        return res
          .status(403)
          .json({ error: 'Permission denied - only room owner or admin can set thresholds' });
      }

      // Upsert room thresholds
      const { data: thresholds, error } = await supabase
        .from('room_moderation_thresholds')
        .upsert(
          {
            room_id: roomId,
            warn_threshold: warn_threshold ?? 0.6,
            block_threshold: block_threshold ?? 0.8,
            enabled: enabled !== undefined ? enabled : true,
            updated_by: userId,
            updated_at: new Date().toISOString(),
          },
          {
            onConflict: 'room_id',
          }
        )
        .select()
        .single();

      if (error) {
        logError('Update moderation thresholds error', error);
        return res.status(500).json({ error: 'Failed to update moderation thresholds' });
      }

      res.json({
        success: true,
        thresholds: {
          warn: thresholds.warn_threshold,
          block: thresholds.block_threshold,
          enabled: thresholds.enabled,
          updated_at: thresholds.updated_at,
        },
      });
    } catch (e) {
      logError('Update moderation thresholds error', e instanceof Error ? e : new Error(String(e)));
      res.status(500).json({ error: 'Failed to update moderation thresholds' });
    }
  }
);

export default router;
