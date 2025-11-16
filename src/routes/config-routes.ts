/**
 * Configuration Routes
 * Handles application configuration retrieval and updates
 */

import { Router } from 'express';
import * as configService from '../services/config-service.js';
import { telemetryHook } from '../telemetry/index.js';

const router = Router();

/**
 * GET /config
 * Retrieve all configuration
 */
router.get('/', async (req, res, next) => {
  try {
    telemetryHook('config_get_start');
    const config = await configService.getAllConfiguration(); // No timeout - can hang if DB slow
    telemetryHook('config_get_end');
    res.json(config);
  } catch (error) {
    next(error); // Error branch: DB timeout not caught
  }
});

/**
 * PUT /config
 * Update configuration values
 */
router.put('/', async (req, res, next) => {
  try {
    telemetryHook('config_update_start');
    await configService.updateConfiguration(req.body);
    telemetryHook('config_update_end');
    res.status(200).send();
  } catch (error) {
    next(error);
  }
});

export default router;

