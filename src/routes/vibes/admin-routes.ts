/**
 * VIBES Admin Routes
 * Administrative endpoints for card management
 */

import express from 'express';
import { authMiddleware } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin-auth.js';
import { getCard, burnCard } from '../../services/vibes/card-generator.js';
import { getRedactedCards } from '../../services/vibes/museum-service.js';
import { getVIBESAnalytics } from '../../services/vibes/analytics-service.js';
import { logError } from '../../shared/logger.js';

const router = express.Router();

// All routes in this file require admin privileges

// Get all cards (admin)
router.get('/cards', authMiddleware, requireAdmin, async (req, res, next) => {
  try {
    // TODO: Implement admin card listing with pagination
    res.json({ message: 'Admin card listing - TODO' });
  } catch (error) {
    logError('Failed to get admin cards', error);
    next(error);
  }
});

// Get redacted cards
router.get('/cards/redacted', authMiddleware, requireAdmin, async (req, res, next) => {
  try {
    const cards = await getRedactedCards();
    res.json({ cards });
  } catch (error) {
    logError('Failed to get redacted cards', error);
    next(error);
  }
});

// Burn card
router.post('/cards/:id/burn', authMiddleware, requireAdmin, async (req, res, next) => {
  try {
    const { reason } = req.body;
    await burnCard(req.params.id, reason);
    res.json({ success: true });
  } catch (error) {
    logError('Failed to burn card', error);
    next(error);
  }
});

// Get card statistics
router.get('/stats', authMiddleware, requireAdmin, async (req, res, next) => {
  try {
    const analytics = await getVIBESAnalytics();
    res.json(analytics);
  } catch (error) {
    logError('Failed to get stats', error);
    next(error);
  }
});

export default router;
