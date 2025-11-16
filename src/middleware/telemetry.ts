/**
 * Simple telemetry middleware that forwards a small event to prom-client via telemetryHook
 */

import { Request, Response, NextFunction } from 'express';
import { telemetryHook } from '../../telemetry/index.js';

export const telemetryMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const path = req.path || '/';
  telemetryHook(`request_${req.method}_${path.replace(/\//g,'_')}`);
  next();
};

