/**
 * Structured Logging Middleware
 * JSON logs with request IDs for production monitoring
 */

import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';
import { logInfo, logError } from '../../shared/logger.js';

interface LogEntry {
  timestamp: string;
  level: 'info' | 'warn' | 'error' | 'debug';
  requestId: string;
  correlationId?: string; // Phase 6.1: Correlation ID for cross-service tracing
  method: string;
  path: string;
  statusCode?: number;
  duration?: number;
  ip?: string;
  userAgent?: string;
  userId?: string;
  error?: string;
  metadata?: Record<string, any>;
  service?: string; // Service name for log aggregation
}

/**
 * Generate request ID and correlation ID, add structured logging
 * Phase 6.1: Enhanced with correlation IDs for cross-service tracing
 */
export function structuredLogging(req: Request, res: Response, next: NextFunction): void {
  const requestId = randomUUID();
  const correlationId = (req.headers['x-correlation-id'] as string) || randomUUID(); // Use existing or generate new
  const startTime = Date.now();

  // Attach IDs to request object for propagation
  (req as any).requestId = requestId;
  (req as any).correlationId = correlationId;

  // Set correlation ID in response headers for client propagation
  res.setHeader('X-Correlation-ID', correlationId);
  res.setHeader('X-Request-ID', requestId);

  // Log request start
  const logEntry: LogEntry = {
    timestamp: new Date().toISOString(),
    level: 'info',
    requestId,
    correlationId,
    method: req.method,
    path: req.path,
    ip: req.ip || req.socket.remoteAddress,
    userAgent: req.headers['user-agent'],
    userId: (req as any).user?.id || (req as any).user?.userId,
    service: process.env.SERVICE_NAME || 'vibez-api',
  };

  // Log request (structured JSON for log aggregation)
  console.log(JSON.stringify({ ...logEntry, event: 'request_start' }));

  // Override res.json to log response
  const originalJson = res.json.bind(res);
  res.json = function (body: any) {
    const duration = Date.now() - startTime;
    const responseLog: LogEntry = {
      ...logEntry,
      statusCode: res.statusCode,
      duration,
      event: 'request_complete',
    };

    // Use appropriate log level based on status code
    responseLog.level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info';

    console.log(JSON.stringify(responseLog));
    return originalJson(body);
  };

  // Log errors
  res.on('finish', () => {
    if (res.statusCode >= 400) {
      const errorLog: LogEntry = {
        ...logEntry,
        level: res.statusCode >= 500 ? 'error' : 'warn',
        statusCode: res.statusCode,
        duration: Date.now() - startTime,
        event: 'request_error',
      };
      console.error(JSON.stringify(errorLog));
    }
  });

  next();
}

/**
 * Log error with request context
 * Phase 6.1: Enhanced with correlation ID
 */
export function logErrorWithContext(
  error: Error,
  req: Request,
  metadata?: Record<string, any>
): void {
  const requestId = (req as any).requestId || 'unknown';
  const correlationId = (req as any).correlationId || 'unknown';
  const logEntry: LogEntry = {
    timestamp: new Date().toISOString(),
    level: 'error',
    requestId,
    correlationId,
    method: req.method,
    path: req.path,
    error: error.message,
    metadata: {
      ...metadata,
      stack: error.stack,
    },
    service: process.env.SERVICE_NAME || 'vibez-api',
    event: 'error',
  };

  console.error(JSON.stringify(logEntry));
  logError(error.message, error);
}

/**
 * Get correlation ID from request (for propagation to other services)
 * Phase 6.1: Helper for cross-service tracing
 */
export function getCorrelationId(req: Request): string {
  return (req as any).correlationId || (req as any).requestId || 'unknown';
}

/**
 * Get request ID from request
 */
export function getRequestId(req: Request): string {
  return (req as any).requestId || 'unknown';
}
