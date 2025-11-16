/**
 * Read Receipts Routes
 * API endpoints for marking messages as read/delivered
 */

import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { markRead, markDelivered, markMultipleRead, getReadReceipts, getRoomReadStatus } from '../services/read-receipts-service.js';
import { logError } from '../shared/logger.js';

const router = Router();

/**
 * POST /read-receipts/read
 * Mark a message as read
 */
router.post('/read', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { message_id } = req.body;
    const userId = req.user?.userId;

    if (!message_id) {
      return res.status(400).json({ error: 'message_id is required' });
    }

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    await markRead(message_id, userId);
    res.json({ success: true, message_id });
  } catch (error: any) {
    logError('Failed to mark message as read', error);
    res.status(500).json({ error: 'Failed to mark message as read', message: error.message });
  }
});

/**
 * POST /read-receipts/delivered
 * Mark a message as delivered
 */
router.post('/delivered', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { message_id } = req.body;
    const userId = req.user?.userId;

    if (!message_id) {
      return res.status(400).json({ error: 'message_id is required' });
    }

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    await markDelivered(message_id, userId);
    res.json({ success: true, message_id });
  } catch (error: any) {
    logError('Failed to mark message as delivered', error);
    res.status(500).json({ error: 'Failed to mark message as delivered', message: error.message });
  }
});

/**
 * POST /read-receipts/batch-read
 * Mark multiple messages as read
 */
router.post('/batch-read', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { message_ids } = req.body;
    const userId = req.user?.userId;

    if (!Array.isArray(message_ids) || message_ids.length === 0) {
      return res.status(400).json({ error: 'message_ids array is required' });
    }

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    await markMultipleRead(message_ids, userId);
    res.json({ success: true, count: message_ids.length });
  } catch (error: any) {
    logError('Failed to mark multiple messages as read', error);
    res.status(500).json({ error: 'Failed to mark messages as read', message: error.message });
  }
});

/**
 * GET /read-receipts/:message_id
 * Get read receipts for a message
 */
router.get('/:message_id', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { message_id } = req.params;
    const receipts = await getReadReceipts(message_id);
    res.json({ receipts });
  } catch (error: any) {
    logError('Failed to get read receipts', error);
    res.status(500).json({ error: 'Failed to get read receipts', message: error.message });
  }
});

/**
 * GET /read-receipts/room/:room_id
 * Get read status for all messages in a room
 */
router.get('/room/:room_id', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { room_id } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const status = await getRoomReadStatus(room_id, userId);
    res.json({ status });
  } catch (error: any) {
    logError('Failed to get room read status', error);
    res.status(500).json({ error: 'Failed to get room read status', message: error.message });
  }
});

export default router;

