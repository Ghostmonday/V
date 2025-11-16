/**
 * Nicknames Routes
 */

import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { setNickname, getNickname, getRoomNicknames } from '../services/nickname-service.js';
import { logError } from '../shared/logger.js';

const router = Router();

router.post('/:roomId', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { roomId } = req.params;
    const { nickname } = req.body;
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!nickname) {
      return res.status(400).json({ error: 'nickname is required' });
    }

    const result = await setNickname(userId, roomId, nickname);
    res.json(result);
  } catch (error: any) {
    logError('Failed to set nickname', error);
    res.status(500).json({ error: error.message });
  }
});

router.get('/:roomId', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { roomId } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const nickname = await getNickname(userId, roomId);
    res.json({ nickname });
  } catch (error: any) {
    logError('Failed to get nickname', error);
    res.status(500).json({ error: error.message });
  }
});

router.get('/:roomId/all', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { roomId } = req.params;
    const nicknames = await getRoomNicknames(roomId);
    res.json({ nicknames });
  } catch (error: any) {
    logError('Failed to get room nicknames', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;

