/**
 * Structured Logging Middleware
 * JSON logs with request IDs for production monitoring
 */

import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';
import { logInfo, logError } from '../shared/logger.js';

interface LogEntry {
  timestamp: string;
  requestId: string;
  method: string;
  path: string;
  statusCode?: number;
  duration?: number;
  ip?: string;
  userAgent?: string;
  userId?: string;
  error?: string;
  metadata?: Record<string, any>;
}

/**
 * Generate request ID and add structured logging
 */
export function structuredLogging(req: Request, res: Response, next: NextFunction): void {
  const requestId = randomUUID();
  const startTime = Date.now();
  
  // Attach request ID to request object
  (req as any).requestId = requestId;
  
  // Log request start
  const logEntry: LogEntry = {
    timestamp: new Date().toISOString(),
    requestId,
    method: req.method,
    path: req.path,
    ip: req.ip || req.socket.remoteAddress,
    userAgent: req.headers['user-agent'],
    userId: (req as any).user?.id || (req as any).user?.userId,
  };
  
  // Log request (structured JSON)
  console.log(JSON.stringify({ ...logEntry, event: 'request_start' }));
  
  // Override res.json to log response
  const originalJson = res.json.bind(res);
  res.json = function(body: any) {
    const duration = Date.now() - startTime;
    const responseLog: LogEntry = {
      ...logEntry,
      statusCode: res.statusCode,
      duration,
      event: 'request_complete',
    };
    
    console.log(JSON.stringify(responseLog));
    return originalJson(body);
  };
  
  // Log errors
  res.on('finish', () => {
    if (res.statusCode >= 400) {
      const errorLog: LogEntry = {
        ...logEntry,
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
 */
export function logErrorWithContext(
  error: Error,
  req: Request,
  metadata?: Record<string, any>
): void {
  const requestId = (req as any).requestId || 'unknown';
  const logEntry: LogEntry = {
    timestamp: new Date().toISOString(),
    requestId,
    method: req.method,
    path: req.path,
    error: error.message,
    metadata: {
      ...metadata,
      stack: error.stack,
    },
    event: 'error',
  };
  
  console.error(JSON.stringify(logEntry));
  logError(error.message, error);
}

