/**
 * User Settings Routes
 */

import { Router, Response } from 'express';
import { authMiddleware } from '../middleware/auth/supabase-auth-middleware.js';
import { AuthenticatedRequest } from '../types/auth-types.js';
import { updateQuietHours, updateMood } from '../services/user-settings-service.js';
import { logError } from '../shared/logger-shared.js';

const router = Router();

router.put('/quiet-hours', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
    try {
        const userId = req.user?.userId;
        const { enabled, start, end } = req.body;

        if (!userId) {
            res.status(401).json({ error: 'Unauthorized' });
            return;
        }

        await updateQuietHours(userId, enabled, start, end);
        res.json({ success: true });
    } catch (error: any) {
        logError('Failed to update quiet hours', error);
        res.status(500).json({ error: error.message });
    }
});

router.put('/mood', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
    try {
        const userId = req.user?.userId;
        const { mood } = req.body;

        if (!userId) {
            res.status(401).json({ error: 'Unauthorized' });
            return;
        }

        await updateMood(userId, mood);
        res.json({ success: true });
    } catch (error: any) {
        logError('Failed to update mood', error);
        res.status(500).json({ error: error.message });
    }
});

export default router;
