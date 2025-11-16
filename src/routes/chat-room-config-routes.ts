/**
 * Chat Room Config Routes
 * Manage room configuration including AI moderation settings
 */

import { Router } from 'express';
import { supabase } from '../config/db.js';
import { logError } from '../shared/logger.js';
import { authMiddleware } from '../middleware/auth.js';
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
      return res.status(403).json({ error: 'Permission denied - only room owner can update config' });
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

export default router;

