/**
 * Error handler middleware
 * SECURITY: Never exposes internal error details to clients
 */

import { Request, Response, NextFunction } from 'express';
import { telemetryHook } from '../../telemetry/index.js';
import { logError } from '../../shared/logger.js';

export const errorMiddleware = (err: Error, req: Request, res: Response, next: NextFunction) => {
  // Log full error details server-side only
  logError('Request error', err);
  
  // Track error in telemetry (non-blocking)
  try {
    telemetryHook(`error_${err.name}`);
  } catch (telemetryError) {
    // Silent fail: telemetry failure shouldn't block error response
    logError('Telemetry hook failed', telemetryError instanceof Error ? telemetryError : new Error(String(telemetryError)));
  }
  
  // SECURITY: Never expose error.message or stack to clients
  // Only return generic error message
  const isDevelopment = process.env.NODE_ENV === 'development';
  res.status(500).json({ 
    error: 'Something broke on our end. We\'ve been notified and are looking into it.',
    // Only include message in development for debugging
    ...(isDevelopment && { debug: err.message })
  });
};

