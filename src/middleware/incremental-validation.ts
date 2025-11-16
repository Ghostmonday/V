/**
 * Incremental Validation Middleware
 * Validates data at every point where validation becomes possible
 * Implements defense-in-depth validation strategy
 */

import { Request, Response, NextFunction } from 'express';
import { z, ZodSchema, ZodError } from 'zod';
import { logError, logWarning } from '../shared/logger.js';

export class ValidationError extends Error {
  constructor(
    public field: string,
    public value: unknown,
    public reason: string,
    public path?: string[]
  ) {
    super(`Validation failed for ${field}: ${reason}`);
    this.name = 'ValidationError';
  }
}

/**
 * Validation context tracks validation state through request lifecycle
 */
interface ValidationContext {
  validated: Set<string>;
  errors: ValidationError[];
  warnings: string[];
}

declare global {
  namespace Express {
    interface Request {
      validation?: ValidationContext;
    }
  }
}

/**
 * Initialize validation context
 */
function initValidationContext(req: Request): ValidationContext {
  if (!req.validation) {
    req.validation = {
      validated: new Set(),
      errors: [],
      warnings: [],
    };
  }
  return req.validation;
}

/**
 * Validate field incrementally (validates as soon as field is available)
 */
export function validateField<T>(
  field: string,
  value: unknown,
  schema: ZodSchema<T>,
  context?: ValidationContext
): T | null {
  try {
    const result = schema.parse(value);
    if (context) {
      context.validated.add(field);
    }
    return result;
  } catch (error) {
    if (error instanceof z.ZodError) {
      const validationError = new ValidationError(
        field,
        value,
        error.errors[0]?.message || 'Invalid format',
        error.errors[0]?.path.map(String)
      );
      if (context) {
        context.errors.push(validationError);
      }
      logWarning(`Validation failed for ${field}`, validationError);
    }
    return null;
  }
}

/**
 * Validate request body incrementally
 */
export function validateBodyIncremental<T>(
  schema: ZodSchema<T>
): (req: Request, res: Response, next: NextFunction) => void {
  return (req: Request, res: Response, next: NextFunction) => {
    const context = initValidationContext(req);
    
    try {
      // Validate entire body
      const result = schema.parse(req.body);
      req.body = result;
      
      // Mark all schema fields as validated
      if (schema instanceof z.ZodObject) {
        Object.keys(schema.shape).forEach(field => {
          context.validated.add(`body.${field}`);
        });
      }
      
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        const errors = error.errors.map(err => ({
          field: err.path.join('.'),
          message: err.message,
          value: err.input,
        }));
        
        context.errors.push(...errors.map(e => 
          new ValidationError(e.field, e.value, e.message, err.path.map(String))
        ));
        
        return res.status(400).json({
          error: 'Validation failed',
          details: errors,
        });
      }
      next(error);
    }
  };
}

/**
 * Validate query parameters incrementally
 */
export function validateQueryIncremental<T>(
  schema: ZodSchema<T>
): (req: Request, res: Response, next: NextFunction) => void {
  return (req: Request, res: Response, next: NextFunction) => {
    const context = initValidationContext(req);
    
    try {
      const result = schema.parse(req.query);
      req.query = result as any;
      
      if (schema instanceof z.ZodObject) {
        Object.keys(schema.shape).forEach(field => {
          context.validated.add(`query.${field}`);
        });
      }
      
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        const errors = error.errors.map(err => ({
          field: err.path.join('.'),
          message: err.message,
        }));
        
        return res.status(400).json({
          error: 'Invalid query parameters',
          details: errors,
        });
      }
      next(error);
    }
  };
}

/**
 * Validate params incrementally
 */
export function validateParamsIncremental<T>(
  schema: ZodSchema<T>
): (req: Request, res: Response, next: NextFunction) => void {
  return (req: Request, res: Response, next: NextFunction) => {
    const context = initValidationContext(req);
    
    try {
      const result = schema.parse(req.params);
      req.params = result as any;
      
      if (schema instanceof z.ZodObject) {
        Object.keys(schema.shape).forEach(field => {
          context.validated.add(`params.${field}`);
        });
      }
      
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({
          error: 'Invalid route parameters',
          details: error.errors.map(err => ({
            field: err.path.join('.'),
            message: err.message,
          })),
        });
      }
      next(error);
    }
  };
}

/**
 * Validate data in service functions (called incrementally)
 */
export function validateServiceData<T>(
  data: unknown,
  schema: ZodSchema<T>,
  context?: string
): T {
  try {
    return schema.parse(data);
  } catch (error) {
    if (error instanceof z.ZodError) {
      const field = error.errors[0]?.path.join('.') || 'unknown';
      const message = error.errors[0]?.message || 'Invalid data';
      logError(`Service validation failed${context ? ` in ${context}` : ''}`, {
        field,
        message,
        value: data,
      });
      throw new ValidationError(field, data, message, error.errors[0]?.path.map(String));
    }
    throw error;
  }
}

/**
 * Validate before database operation
 */
export function validateBeforeDB<T>(
  data: unknown,
  schema: ZodSchema<T>,
  operation: string
): T {
  try {
    const validated = schema.parse(data);
    logWarning(`Pre-DB validation passed for ${operation}`, { fields: Object.keys(validated) });
    return validated;
  } catch (error) {
    if (error instanceof z.ZodError) {
      logError(`Pre-DB validation failed for ${operation}`, error);
      throw new ValidationError(
        'database_input',
        data,
        `Invalid data for ${operation}: ${error.errors[0]?.message}`,
        error.errors[0]?.path.map(String)
      );
    }
    throw error;
  }
}

/**
 * Validate after database fetch (validate data integrity)
 */
export function validateAfterDB<T>(
  data: unknown,
  schema: ZodSchema<T>,
  source: string
): T {
  try {
    return schema.parse(data);
  } catch (error) {
    if (error instanceof z.ZodError) {
      logError(`Post-DB validation failed for ${source}`, {
        error: error.errors,
        data,
      });
      // Don't throw - log and return partial data
      // This indicates data corruption or schema mismatch
      throw new ValidationError(
        'database_output',
        data,
        `Data integrity check failed for ${source}`,
        error.errors[0]?.path.map(String)
      );
    }
    throw error;
  }
}

/**
 * Validate response before sending (final validation)
 */
export function validateResponse<T>(
  data: unknown,
  schema: ZodSchema<T>
): T {
  try {
    return schema.parse(data);
  } catch (error) {
    if (error instanceof z.ZodError) {
      logError('Response validation failed', error);
      // Return sanitized error response
      return {
        error: 'Response validation failed',
        details: error.errors.map(e => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      } as T;
    }
    throw error;
  }
}

/**
 * Middleware to check validation status
 */
export function requireValidated(fields: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const context = req.validation || initValidationContext(req);
    
    const missing: string[] = [];
    for (const field of fields) {
      if (!context.validated.has(field)) {
        missing.push(field);
      }
    }
    
    if (missing.length > 0) {
      return res.status(400).json({
        error: 'Required fields not validated',
        missing,
      });
    }
    
    if (context.errors.length > 0) {
      return res.status(400).json({
        error: 'Validation errors',
        details: context.errors.map(e => ({
          field: e.field,
          message: e.reason,
        })),
      });
    }
    
    next();
  };
}

/**
 * Validate WebSocket message incrementally
 */
export function validateWSMessage<T>(
  message: unknown,
  schema: ZodSchema<T>
): T {
  try {
    return schema.parse(message);
  } catch (error) {
    if (error instanceof z.ZodError) {
      logError('WebSocket message validation failed', error);
      throw new ValidationError(
        'ws_message',
        message,
        `Invalid WebSocket message: ${error.errors[0]?.message}`,
        error.errors[0]?.path.map(String)
      );
    }
    throw error;
  }
}

/**
 * Validate transformation result (after data transformation)
 */
export function validateTransformation<T>(
  before: unknown,
  after: unknown,
  schema: ZodSchema<T>,
  transformation: string
): T {
  try {
    const validated = schema.parse(after);
    logWarning(`Transformation validation passed: ${transformation}`, {
      beforeType: typeof before,
      afterType: typeof after,
    });
    return validated;
  } catch (error) {
    if (error instanceof z.ZodError) {
      logError(`Transformation validation failed: ${transformation}`, {
        error: error.errors,
        before,
        after,
      });
      throw new ValidationError(
        'transformation_output',
        after,
        `Invalid output from ${transformation}`,
        error.errors[0]?.path.map(String)
      );
    }
    throw error;
  }
}

