import { Router, Request, Response, NextFunction } from 'express';
import { authMiddleware } from '../middleware/auth/supabase-auth-middleware.js';
import { AuthenticatedRequest } from '../types/auth-types.js';
import { scheduleCall, getRoomScheduledCalls } from '../services/scheduling-service.js';
import { logError } from '../shared/logger-shared.js';

const router = Router();

router.post('/', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { userId } = (req as unknown as AuthenticatedRequest).user;
        const { roomId, scheduledAt, title } = req.body;

        if (!roomId || !scheduledAt) {
            res.status(400).json({ error: 'Room ID and scheduled time are required' });
            return;
        }

        const call = await scheduleCall(userId, roomId, scheduledAt, title);
        res.status(201).json(call);
        return;
    } catch (error: any) {
        logError('Error scheduling call', error);
        res.status(500).json({ error: 'Failed to schedule call' });
        return;
    }
});

router.get('/room/:roomId', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { roomId } = req.params;
        const calls = await getRoomScheduledCalls(roomId);
        res.status(200).json(calls);
        return;
    } catch (error: any) {
        logError('Error fetching scheduled calls', error);
        res.status(500).json({ error: 'Failed to fetch scheduled calls' });
        return;
    }
});

export default router;
