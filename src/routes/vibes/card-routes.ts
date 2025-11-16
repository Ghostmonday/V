/**
 * VIBES Card Routes
 * API endpoints for card operations
 */

import express from 'express';
import { authMiddleware } from '../../middleware/auth.js';
import {
  getCard,
  burnCard,
} from '../../services/vibes/card-generator.js';
import {
  claimCard,
  declineCard,
  getUserCards,
  getCardOwnership,
} from '../../services/vibes/ownership-service.js';
import { logError } from '../../shared/logger.js';
import { VIBESError } from '../../services/vibes/error-handler.js';

const router = express.Router();

// Get user's cards
router.get('/my-cards', authMiddleware, async (req, res, next) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const cards = await getUserCards(userId);
    res.json({ cards });
  } catch (error) {
    logError('Failed to get user cards', error);
    next(error);
  }
});

// Get card by ID
router.get('/:id', authMiddleware, async (req, res, next) => {
  try {
    const card = await getCard(req.params.id);
    res.json({ card });
  } catch (error) {
    if (error instanceof VIBESError) {
      return res.status(error.statusCode).json({ error: error.message, code: error.code });
    }
    next(error);
  }
});

// Claim card
router.post('/:id/claim', authMiddleware, async (req, res, next) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const ownership = await claimCard(req.params.id, userId);
    res.json({ ownership });
  } catch (error) {
    logError('Failed to claim card', error);
    next(error);
  }
});

// Decline card
router.post('/:id/decline', authMiddleware, async (req, res, next) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    await declineCard(req.params.id, userId);
    res.json({ success: true });
  } catch (error) {
    logError('Failed to decline card', error);
    next(error);
  }
});

// Get card ownership
router.get('/:id/ownership', authMiddleware, async (req, res, next) => {
  try {
    const ownership = await getCardOwnership(req.params.id);
    res.json({ ownership });
  } catch (error) {
    logError('Failed to get ownership', error);
    next(error);
  }
});

// Burn card (admin only - TODO: add admin check)
router.post('/:id/burn', authMiddleware, async (req, res, next) => {
  try {
    const { reason } = req.body;
    await burnCard(req.params.id, reason);
    res.json({ success: true });
  } catch (error) {
    logError('Failed to burn card', error);
    next(error);
  }
});

export default router;
