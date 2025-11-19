/**
 * Pinned Items Routes
 */

import { Router, Response } from 'express';
import { authMiddleware } from '../middleware/auth/supabase-auth-middleware.js';
import { AuthenticatedRequest } from '../types/auth-types.js';
import {
  pinRoom,
  unpinRoom,
  getPinnedRooms,
  isRoomPinned,
  pinMessage,
  unpinMessage,
} from '../services/pinned-items-service.js';
import { logError } from '../shared/logger-shared.js';

const router = Router();

router.post('/:roomId', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { roomId } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    await pinRoom(userId, roomId);
    res.json({ success: true });
  } catch (error: any) {
    logError('Failed to pin room', error);
    res.status(500).json({ error: error.message });
  }
});

router.delete('/:roomId', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { roomId } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    await unpinRoom(userId, roomId);
    res.json({ success: true });
  } catch (error: any) {
    logError('Failed to unpin room', error);
    res.status(500).json({ error: error.message });
  }
});

router.get('/', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const pinned = await getPinnedRooms(userId);
    res.json({ pinned });
  } catch (error: any) {
    logError('Failed to get pinned rooms', error);
    res.status(500).json({ error: error.message });
  }
});

router.get('/:roomId/check', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { roomId } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const pinned = await isRoomPinned(userId, roomId);
    res.json({ pinned });
  } catch (error: any) {
    logError('Failed to check if room is pinned', error);
    res.status(500).json({ error: error.message });
  }
});

router.post('/messages/:messageId', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { messageId } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    await pinMessage(messageId);
    res.json({ success: true });
  } catch (error: any) {
    logError('Failed to pin message', error);
    res.status(500).json({ error: error.message });
  }
});

router.delete('/messages/:messageId', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { messageId } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    await unpinMessage(messageId);
    res.json({ success: true });
  } catch (error: any) {
    logError('Failed to unpin message', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
