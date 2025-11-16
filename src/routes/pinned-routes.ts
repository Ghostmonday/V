/**
 * Pinned Items Routes
 */

import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { pinRoom, unpinRoom, getPinnedRooms, isRoomPinned } from '../services/pinned-items-service.js';
import { logError } from '../shared/logger.js';

const router = Router();

router.post('/:roomId', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { roomId } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    await pinRoom(userId, roomId);
    res.json({ success: true });
  } catch (error: any) {
    logError('Failed to pin room', error);
    res.status(500).json({ error: error.message });
  }
});

router.delete('/:roomId', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { roomId } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    await unpinRoom(userId, roomId);
    res.json({ success: true });
  } catch (error: any) {
    logError('Failed to unpin room', error);
    res.status(500).json({ error: error.message });
  }
});

router.get('/', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const pinned = await getPinnedRooms(userId);
    res.json({ pinned });
  } catch (error: any) {
    logError('Failed to get pinned rooms', error);
    res.status(500).json({ error: error.message });
  }
});

router.get('/:roomId/check', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { roomId } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const pinned = await isRoomPinned(userId, roomId);
    res.json({ pinned });
  } catch (error: any) {
    logError('Failed to check if room is pinned', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;

