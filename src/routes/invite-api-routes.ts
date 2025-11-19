/**
 * Invite Routes
 */

import { Router, Request, Response, NextFunction } from 'express';
import { authMiddleware } from '../middleware/auth/supabase-auth-middleware.js';
import { AuthenticatedRequest } from '../types/auth-types.js';
import { createInvite, useInvite } from '../services/invite-service.js';
import { logError } from '../shared/logger-shared.js';

const router = Router();

router.post('/', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { userId } = (req as unknown as AuthenticatedRequest).user;
        const { roomId, maxUses, expiresAt, customCode } = req.body;

        if (!roomId) {
            res.status(400).json({ error: 'Room ID is required' });
            return;
        }

        const invite = await createInvite(userId, roomId, { maxUses, expiresAt, customCode });
        res.status(201).json(invite);
        return;
    } catch (error: any) {
        logError('Error creating invite', error);
        res.status(500).json({ error: 'Failed to create invite' });
        return;
    }
});

router.post('/:code/use', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { code } = req.params;
        // useInvite just validates and increments usage. 
        // The actual joining logic should happen in room-service or client side after validation.
        const success = await useInvite(code);

        if (!success) {
            res.status(400).json({ error: 'Invalid or expired invite' });
            return;
        }

        res.status(200).json({ success: true });
        return;
    } catch (error: any) {
        logError('Error using invite', error);
        res.status(500).json({ error: 'Failed to use invite' });
        return;
    }
});

export default router;
