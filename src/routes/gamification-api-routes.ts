import { Router, Request, Response, NextFunction } from 'express';
import { authMiddleware } from '../middleware/auth/supabase-auth-middleware.js';
import { AuthenticatedRequest } from '../types/auth-types.js';
import { getUserProgress } from '../services/gamification-service.js';
import { logError } from '../shared/logger-shared.js';

const router = Router();

router.get('/progress', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { userId } = (req as unknown as AuthenticatedRequest).user;
        const progress = await getUserProgress(userId);
        res.status(200).json(progress);
        return;
    } catch (error: any) {
        logError('Error fetching user progress', error);
        res.status(500).json({ error: 'Failed to fetch user progress' });
        return;
    }
});

export default router;
