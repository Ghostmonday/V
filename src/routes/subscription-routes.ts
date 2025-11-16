/**
 * Subscription Routes
 * Handles subscription status, plans, and IAP verification
 */

import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import {
  getUserSubscription,
  getSubscriptionLimits,
  updateSubscription,
  SubscriptionTier
} from '../services/subscription-service.js';
import { getUsageCount, checkUsageLimit } from '../services/usage-service.js';
import { verifyAppleReceipt } from '../services/apple-iap-service.js';
import { AuthenticatedRequest } from '../types/auth.types.js';

const router = Router();
router.use(authMiddleware);

router.get('/status', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user.userId;
    const tier = await getUserSubscription(userId);
    const limits = await getSubscriptionLimits(userId);
    const usage = {
      aiMessages: await getUsageCount(userId, 'ai_message'),
      rooms: await getUsageCount(userId, 'room_created'),
      storageMB: await getUsageCount(userId, 'file_upload')
    };

    res.json({ tier, limits, usage });
  } catch (error) {
    res.status(500).json({ error: 'Failed to get subscription status' });
  }
});

router.post('/verify-receipt', async (req, res) => {
  try {
    const userId = (req as any).user.userId;
    const { receiptData } = req.body;

    if (!receiptData) {
      return res.status(400).json({ error: 'receiptData required' });
    }

    const result = await verifyAppleReceipt(receiptData, userId);
    if (result.verified) {
      res.json({ status: 'verified', tier: result.tier });
    } else {
      res.status(400).json({ error: 'Invalid receipt' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Failed to verify receipt' });
  }
});

router.get('/plans', async (req, res) => {
  res.json({
    plans: [
      {
        id: 'free',
        name: 'Free',
        price: 0,
        features: ['10 AI messages/month', '5 rooms', '100MB storage', '30 min voice calls']
      },
      {
        id: 'pro',
        name: 'Pro',
        price: 9.99,
        features: [
          'Unlimited AI messages',
          'Unlimited rooms',
          '10GB storage',
          'Unlimited voice calls',
          'Screen sharing',
          'Priority support'
        ]
      },
      {
        id: 'team',
        name: 'Team',
        price: 29.99,
        features: [
          'All Pro features',
          'Team management',
          '100GB storage',
          'API access',
          'Advanced moderation'
        ]
      }
    ]
  });
});

export default router;

