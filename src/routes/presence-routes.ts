/**
 * Presence Routes
 * Handles user online/offline status endpoints
 */

import { Router } from 'express';
import * as presenceService from '../services/presence-service.js';
import { telemetryHook } from '../telemetry/index.js';

const router = Router();

/**
 * GET /presence/status
 * Get user presence status
 */
router.get('/status', async (req, res, next) => {
  try {
    telemetryHook('presence_status_start');
    const result = await presenceService.getUserPresenceStatus(req.query.userId as string); // Silent fail: Redis down returns 'offline' (may be wrong)
    telemetryHook('presence_status_end');
    res.json(result);
  } catch (error) {
    next(error); // Error branch: Redis timeout not caught, hangs indefinitely
  }
});

/**
 * POST /presence/update
 * Update user presence status
 */
router.post('/update', async (req, res, next) => {
  try {
    telemetryHook('presence_update_start');
    await presenceService.updateUserPresenceStatus(req.body.userId, req.body.status);
    telemetryHook('presence_update_end');
    res.status(200).send();
  } catch (error) {
    next(error);
  }
});

export default router;

