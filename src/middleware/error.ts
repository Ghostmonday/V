/**
 * Error handler middleware
 * SECURITY: Never exposes internal error details to clients
 * Phase 6.3: Enhanced with error alerting
 */

import { Request, Response, NextFunction } from 'express';
import { telemetryHook } from '../../telemetry/index.js';
import { logError } from '../../shared/logger.js';
import { alertOnError } from './error-alerting.js';
import { logErrorWithContext } from './structured-logging.js';

export const errorMiddleware = (err: Error, req: Request, res: Response, next: NextFunction) => {
  // Log full error details server-side only (with structured logging)
  logErrorWithContext(err, req, {
    statusCode: res.statusCode || 500,
    path: req.path,
    method: req.method,
  });

  // Phase 6.3: Alert on errors (non-blocking)
  try {
    // Determine error type from path/context
    let errorType: 'auth' | 'db' | 'ws' | 'api' | 'moderation' = 'api';
    if (req.path.includes('/auth')) errorType = 'auth';
    else if (req.path.includes('/admin/moderation') || req.path.includes('/api/moderation'))
      errorType = 'moderation';
    else if (req.path.includes('/ws') || req.path.includes('/socket')) errorType = 'ws';

    // Determine severity (db errors are critical)
    const severity = errorType === 'db' ? 'critical' : 'error';

    alertOnError(err, {
      type: errorType,
      endpoint: req.path,
      userId: (req as any).user?.id || (req as any).user?.userId,
      severity,
      metadata: {
        method: req.method,
        statusCode: res.statusCode || 500,
      },
    }).catch((alertError) => {
      // Silent fail: alerting failure shouldn't block error response
      logError(
        'Error alerting failed',
        alertError instanceof Error ? alertError : new Error(String(alertError))
      );
    });
  } catch (alertError) {
    // Silent fail: alerting failure shouldn't block error response
    logError(
      'Error alerting setup failed',
      alertError instanceof Error ? alertError : new Error(String(alertError))
    );
  }

  // Track error in telemetry (non-blocking)
  try {
    telemetryHook(`error_${err.name}`);
  } catch (telemetryError) {
    // Silent fail: telemetry failure shouldn't block error response
    logError(
      'Telemetry hook failed',
      telemetryError instanceof Error ? telemetryError : new Error(String(telemetryError))
    );
  }

  // SECURITY: Never expose error.message or stack to clients
  // Only return generic error message
  const isDevelopment = process.env.NODE_ENV === 'development';
  res.status(500).json({
    error: "Something broke on our end. We've been notified and are looking into it.",
    // Only include message in development for debugging
    ...(isDevelopment && { debug: err.message }),
  });
};
