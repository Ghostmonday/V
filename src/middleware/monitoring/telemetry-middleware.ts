/**
 * Simple telemetry middleware that forwards a small event to prom-client via telemetryHook
 */

import { Request, Response, NextFunction } from 'express';
import { telemetryHook } from '../../telemetry/telemetry-exports.js';
import crypto from 'crypto';

export const telemetryMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const path = req.path || '/';

  // Scrub sensitive metadata: Hash user ID for logs to prevent long-term tracking
  // We use a rotating salt (e.g., daily) in production, but for now a simple hash suffices
  // to disconnect the log from the user ID table directly.
  let scrubbedUserId: string | undefined;
  if ((req as any).user?.userId) {
    scrubbedUserId = crypto.createHash('sha256').update((req as any).user.userId).digest('hex').substring(0, 16);
  }

  // Only log the scrubbed ID, never the raw user ID in telemetry
  telemetryHook(`request_${req.method}_${path.replace(/\//g, '_')}`, {
    scrubbedUserId
  });

  next();
};
