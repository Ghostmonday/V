import { Request, Response, NextFunction } from 'express';
import { logError } from '../shared/logger.js';

/**
 * Input validation middleware
 * Validates common request patterns
 */

export function validateUUID(field: string) {
  return (req: Request, res: Response, next: NextFunction) => {
    const value = req.params[field] || req.body[field];
    if (value && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) {
      return res.status(400).json({ error: `Invalid ${field} format` });
    }
    next();
  };
}

export function validateRequired(fields: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const missing: string[] = [];
    for (const field of fields) {
      if (req.body[field] === undefined || req.body[field] === null || req.body[field] === '') {
        missing.push(field);
      }
    }
    if (missing.length > 0) {
      return res.status(400).json({ error: `Missing required fields: ${missing.join(', ')}` });
    }
    next();
  };
}

export function validateStringLength(field: string, maxLength: number, minLength: number = 0) {
  return (req: Request, res: Response, next: NextFunction) => {
    const value = req.body[field];
    if (value !== undefined && typeof value === 'string') {
      if (value.length < minLength) {
        return res.status(400).json({ error: `${field} must be at least ${minLength} characters` });
      }
      if (value.length > maxLength) {
        return res.status(400).json({ error: `${field} must be at most ${maxLength} characters` });
      }
    }
    next();
  };
}

export function sanitizeInput(req: Request, res: Response, next: NextFunction) {
  try {
    // Recursively sanitize string fields
    const sanitize = (obj: unknown): unknown => {
      if (typeof obj === 'string') {
        // Remove null bytes and trim
        return obj.replace(/\0/g, '').trim();
      }
      if (Array.isArray(obj)) {
        return obj.map(sanitize);
      }
      if (obj && typeof obj === 'object') {
        const sanitized: Record<string, unknown> = {};
        for (const [key, value] of Object.entries(obj)) {
          sanitized[key] = sanitize(value);
        }
        return sanitized;
      }
      return obj;
    };

    if (req.body) {
      req.body = sanitize(req.body) as typeof req.body;
    }
    next();
  } catch (error: unknown) {
    const err = error instanceof Error ? error : new Error(String(error));
    logError('Input sanitization error', err);
    res.status(400).json({ error: 'Invalid input format' });
  }
}

