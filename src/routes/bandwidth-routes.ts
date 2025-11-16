/**
 * Bandwidth Routes
 */

import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { getBandwidthMode, setBandwidthMode } from '../services/bandwidth-service.js';
import { logError } from '../shared/logger.js';

const router = Router();

router.get('/', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const mode = await getBandwidthMode(userId);
    res.json({ mode });
  } catch (error: any) {
    logError('Failed to get bandwidth mode', error);
    res.status(500).json({ error: error.message });
  }
});

router.post('/', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { mode } = req.body;
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!['auto', 'low', 'high'].includes(mode)) {
      return res.status(400).json({ error: 'Invalid mode. Must be auto, low, or high' });
    }

    const result = await setBandwidthMode(userId, mode);
    res.json(result);
  } catch (error: any) {
    logError('Failed to set bandwidth mode', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;

