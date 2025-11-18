/**
 * Shared logging utilities
 * Provides consistent logging across the application
 * Production-ready logger abstraction
 */

interface LogContext {
  error?: Error | unknown;
  [key: string]: unknown;
}

export function logInfo(
  message: string,
  context?: Record<string, unknown> | unknown,
  ...args: unknown[]
): void {
  // Support both new signature (context object) and old signature (spread args)
  let contextStr = '';
  if (context && typeof context === 'object' && !Array.isArray(context)) {
    contextStr = ` ${JSON.stringify(context)}`;
  } else if (context || args.length > 0) {
    // Old signature - log all args
    const allArgs = context ? [context, ...args] : args;
    contextStr = ` ${allArgs.map((a) => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' ')}`;
  }

  if (process.env.NODE_ENV !== 'production') {
    console.log(`[VibeZ INFO] ${message}${contextStr}`);
  }
}

export function logWarning(message: string, ...args: unknown[]): void {
  console.warn(`[VibeZ WARN] ${message}`, ...args);
}

export function logError(
  message: string,
  error?: Error | unknown,
  context?: Record<string, unknown>
): void {
  const errorMessage = error instanceof Error ? error.message : String(error || '');
  const contextStr = context ? ` ${JSON.stringify(context)}` : '';
  console.error(`[VibeZ ERROR] ${message}${contextStr}`, errorMessage);
  if (error instanceof Error && process.env.NODE_ENV !== 'production') {
    console.error('Stack trace:', error.stack);
  }
}

// Legacy alias for backward compatibility
export function log(...args: unknown[]): void {
  logInfo(String(args[0] || ''), ...args.slice(1));
}

export function logAudit(
  event: string,
  userId: string,
  metadata?: Record<string, unknown>
): Promise<void> {
  // Audit logging - in production, this would write to an audit log table
  const auditEntry = {
    event,
    userId,
    timestamp: new Date().toISOString(),
    metadata: metadata || {},
  };

  if (process.env.NODE_ENV !== 'production') {
    console.warn(`[VibeZ AUDIT] ${event}`, auditEntry);
  }

  // In production, this would be async and write to database
  return Promise.resolve();
}
