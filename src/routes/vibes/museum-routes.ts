/**
 * VIBES Museum Routes
 * API endpoints for public museum
 */

import express from 'express';
import {
  getPublicCards,
  incrementViewCount,
  getRedactedCards,
} from '../../services/vibes/museum-service.js';
import { logError } from '../../shared/logger.js';

const router = express.Router();

// Get public cards (no auth required)
router.get('/', async (req, res, next) => {
  try {
    const { rarity, featured, limit, offset } = req.query;
    
    const filters = {
      rarity: rarity as string | undefined,
      featured: featured === 'true',
      limit: limit ? parseInt(limit as string, 10) : 20,
      offset: offset ? parseInt(offset as string, 10) : 0,
    };

    const cards = await getPublicCards(filters);
    res.json({ cards });
  } catch (error) {
    logError('Failed to get public cards', error);
    next(error);
  }
});

// Increment view count
router.post('/:cardId/view', async (req, res, next) => {
  try {
    await incrementViewCount(req.params.cardId);
    res.json({ success: true });
  } catch (error) {
    logError('Failed to increment view count', error);
    next(error);
  }
});

// Get redacted cards (admin only - TODO: add admin check)
router.get('/redacted', async (req, res, next) => {
  try {
    const cards = await getRedactedCards();
    res.json({ cards });
  } catch (error) {
    logError('Failed to get redacted cards', error);
    next(error);
  }
});

export default router;
