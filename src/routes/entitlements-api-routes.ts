/**
 * Entitlements Routes
 * Handles subscription entitlements API
 */

import { Router } from 'express';
import { authMiddleware } from '../middleware/auth/supabase-auth-middleware.js';
import { getEntitlements, updateSubscription } from '../services/entitlements.js';
import { AuthenticatedRequest } from '../types/auth-types.js';
import { logError } from '../shared/logger-shared.js';

const router = Router();
router.use(authMiddleware);

/**
 * GET /entitlements
 * Get user's current entitlements
 */
router.get('/', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user.userId;
    const entitlements = await getEntitlements(userId);
    res.json(entitlements || {});
  } catch (error) {
    logError('Failed to get entitlements', error);
    res.status(500).json({ error: 'Failed to get entitlements' });
  }
});

/**
 * POST /subscription
 * Update subscription status (called from iOS after purchase)
 */
router.post('/subscription', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user.userId;
    const { plan, status, renewalDate, entitlements, transactionId, productId } = req.body;

    if (!plan || !status) {
      return res.status(400).json({ error: 'plan and status are required' });
    }

    await updateSubscription(
      userId,
      plan,
      status,
      renewalDate ? new Date(renewalDate) : undefined,
      entitlements,
      transactionId,
      productId
    );

    res.json({ success: true });
  } catch (error) {
    logError('Failed to update subscription', error);
    res.status(500).json({ error: 'Failed to update subscription' });
  }
});

export default router;
