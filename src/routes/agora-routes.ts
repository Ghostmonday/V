/**
 * Agora Routes
 * Handles mute/unmute, video toggle, and room member management
 */

import { Router, Response, NextFunction } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { logError } from '../shared/logger.js';
import { AuthenticatedRequest } from '../types/auth.types.js';

const router = Router();

/**
 * POST /rooms/:id/mute
 * Toggle mute status for current user
 */
router.post('/rooms/:id/mute', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const roomId = req.params.id;
    const { isMuted } = req.body;

    if (typeof isMuted !== 'boolean') {
      return res.status(400).json({ error: 'isMuted must be a boolean' });
    }

    const { updateMemberMute } = await import('../services/agora-service.js');
    const result = await updateMemberMute(roomId, userId, isMuted);

    if (!result.success) {
      return res.status(404).json({ error: 'Room or member not found' });
    }

    res.json({ success: true, isMuted });
  } catch (error) {
    logError('Mute toggle error', error instanceof Error ? error : new Error(String(error)));
    next(error);
  }
});

/**
 * POST /rooms/:id/video
 * Toggle video status for current user
 */
router.post('/rooms/:id/video', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const roomId = req.params.id;
    const { isVideoEnabled } = req.body;

    if (typeof isVideoEnabled !== 'boolean') {
      return res.status(400).json({ error: 'isVideoEnabled must be a boolean' });
    }

    const { updateMemberVideo } = await import('../services/agora-service.js');
    const result = await updateMemberVideo(roomId, userId, isVideoEnabled);

    if (!result.success) {
      return res.status(404).json({ error: 'Room or member not found, or room is voice-only' });
    }

    res.json({ success: true, isVideoEnabled });
  } catch (error) {
    logError('Video toggle error', error instanceof Error ? error : new Error(String(error)));
    next(error);
  }
});

/**
 * GET /rooms/:id/members
 * Get list of room members
 */
router.get('/rooms/:id/members', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const roomId = req.params.id;

    const { getRoomMembers } = await import('../services/agora-service.js');
    const members = await getRoomMembers(roomId);

    res.json({
      success: true,
      members: members.map(m => ({
        userId: m.userId,
        uid: m.uid,
        isMuted: m.isMuted,
        isVideoEnabled: m.isVideoEnabled,
        joinedAt: m.joinedAt,
      })),
    });
  } catch (error) {
    logError('Get members error', error instanceof Error ? error : new Error(String(error)));
    next(error);
  }
});

/**
 * POST /rooms/:id/leave
 * Leave room and clean up state
 */
router.post('/rooms/:id/leave', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const roomId = req.params.id;

    const { removeRoomMember } = await import('../services/agora-service.js');
    await removeRoomMember(roomId, userId);

    res.json({ success: true });
  } catch (error) {
    logError('Leave room error', error instanceof Error ? error : new Error(String(error)));
    next(error);
  }
});

export default router;

