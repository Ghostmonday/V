/**
 * Telemetry Routes
 * Handles telemetry event logging endpoints
 */

import { Router } from 'express';
import * as telemetryService from '../services/telemetry-service.js';
import { telemetryHook } from '../telemetry/telemetry-exports.js';

const router = Router();

/**
 * POST /telemetry/log
 * Record a telemetry event
 */
router.post('/log', async (req, res, next) => {
  try {
    telemetryHook('telemetry_log_start');
    await telemetryService.recordTelemetryEvent(req.body.event);
    telemetryHook('telemetry_log_end');
    res.status(200).send();
  } catch (error) {
    next(error);
  }
});

export default router;
