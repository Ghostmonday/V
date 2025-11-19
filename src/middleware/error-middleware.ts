/**
 * Error handler middleware
 * SECURITY: Never exposes internal error details to clients
 * Phase 6.3: Enhanced with error alerting
 */

import { Request, Response, NextFunction } from 'express';
import { telemetryHook } from '../telemetry/telemetry-exports.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { alertOnError } from './monitoring/error-alerting-middleware.js';
import { logErrorWithContext } from './monitoring/structured-logging-middleware.js';

import { AppError } from '../utils/app-error.js';

export const errorMiddleware = (err: Error, req: Request, res: Response, next: NextFunction) => {
  // Normalize error
  let error = err;
  let statusCode = (res as any).statusCode === 200 ? 500 : (res as any).statusCode || 500;
  let message = err.message;

  // Handle AppError
  if (err instanceof AppError) {
    statusCode = err.statusCode;
    message = err.message;
  }
  // Handle Zod Validation Errors (check by name to avoid import issues)
  else if (err.name === 'ZodError' || (err as any).issues) {
    statusCode = 400;
    message = 'Validation Error';
  }
  // Handle Supabase/Postgres Errors (basic mapping)
  else if ((err as any).code) {
    const code = (err as any).code;
    if (code === '23505') { // Unique violation
      statusCode = 409;
      message = 'Duplicate entry';
    } else if (code === '23503') { // Foreign key violation
      statusCode = 400;
      message = 'Invalid reference';
    }
  }

  // Log full error details server-side only (with structured logging)
  logErrorWithContext(err, req, {
    statusCode,
    path: (req as any).path,
    method: (req as any).method,
    errorType: err.constructor.name,
  });

  // Phase 6.3: Alert on errors (non-blocking)
  try {
    // Determine error type from path/context
    let errorType: 'auth' | 'db' | 'ws' | 'api' | 'moderation' = 'api';
    const path = (req as any).path || '';
    if (path.includes('/auth')) errorType = 'auth';
    else if (path.includes('/admin/moderation') || path.includes('/api/moderation'))
      errorType = 'moderation';
    else if (path.includes('/ws') || path.includes('/socket')) errorType = 'ws';
    else if ((err as any).code || (err as any).hint) errorType = 'db';

    // Determine severity (db errors are critical, 500s are error, 4xx are warning/info)
    const severity = errorType === 'db' || statusCode >= 500 ? 'error' : 'warning';

    // Only alert on 500s or critical DB errors to reduce noise
    if (statusCode >= 500) {
      alertOnError(err, {
        type: errorType,
        endpoint: path || 'unknown',
        userId: (req as any).user?.id || (req as any).user?.userId,
        severity,
        metadata: {
          method: (req as any).method,
          statusCode,
        },
      }).catch((alertError: any) => {
        // Silent fail
        logError(
          'Error alerting failed',
          alertError instanceof Error ? alertError : new Error(String(alertError))
        );
      });
    }
  } catch (alertError) {
    // Silent fail
    logError(
      'Error alerting setup failed',
      alertError instanceof Error ? alertError : new Error(String(alertError))
    );
  }

  // Track error in telemetry (non-blocking)
  try {
    telemetryHook(`error_${statusCode}_${err.name}`);
  } catch (telemetryError) {
    // Silent fail
    logError(
      'Telemetry hook failed',
      telemetryError instanceof Error ? telemetryError : new Error(String(telemetryError))
    );
  }

  // SECURITY: Never expose internal error details to clients in production
  const isDevelopment = process.env.NODE_ENV === 'development';

  res.status(statusCode).json({
    success: false,
    error: statusCode >= 500 ? 'Internal Server Error' : message,
    ...(isDevelopment && {
      debug: err.message,
      stack: err.stack,
      details: (err as any).errors || (err as any).issues // Zod errors
    }),
  });
};
