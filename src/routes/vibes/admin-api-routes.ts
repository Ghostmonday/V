/**
 * VIBES Admin Routes
 * Administrative endpoints for VIBES system
 */

import express from 'express';
import { authMiddleware } from '../middleware/supabase-auth.js';
import { requireAdmin } from '../../middleware/admin-auth.js';
import { getVIBESAnalytics } from '../../services/vibes/analytics-service.js';
import { logError } from '../../shared/logger.js';

const router = express.Router();

// All routes in this file require admin privileges

// Get statistics
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
