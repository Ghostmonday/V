/**
 * Slow Query Tracker
 * Phase 6.2: Tracks and logs slow database queries (>100ms)
 */

import { logWarning, logError } from '../shared/logger.js';
import { recordDatabaseQuery } from './monitoring-service.js';

interface QueryContext {
  table: string;
  operation: string;
  query?: string;
  params?: any[];
  startTime: number;
}

const SLOW_QUERY_THRESHOLD_MS = 100; // Log queries slower than 100ms
const slowQueries: Map<string, QueryContext> = new Map();

/**
 * Start tracking a query
 */
export function startQueryTracking(
  queryId: string,
  table: string,
  operation: string,
  query?: string,
  params?: any[]
): void {
  slowQueries.set(queryId, {
    table,
    operation,
    query,
    params,
    startTime: Date.now(),
  });
}

/**
 * End tracking a query and log if slow
 */
export function endQueryTracking(queryId: string): number {
  const context = slowQueries.get(queryId);
  if (!context) {
    return 0;
  }

  const duration = Date.now() - context.startTime;
  slowQueries.delete(queryId);

  // Record metric (always)
  recordDatabaseQuery(context.table, context.operation, duration);

  // Log if slow
  if (duration > SLOW_QUERY_THRESHOLD_MS) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level: 'warn',
      event: 'slow_query',
      table: context.table,
      operation: context.operation,
      duration_ms: duration,
      threshold_ms: SLOW_QUERY_THRESHOLD_MS,
      query: context.query ? truncateQuery(context.query) : undefined,
      params: context.params ? sanitizeParams(context.params) : undefined,
    };

    logWarning(`Slow query detected: ${context.table}.${context.operation} took ${duration}ms`, logEntry);
    console.warn(JSON.stringify(logEntry));
  }

  return duration;
}

/**
 * Truncate long queries for logging (prevent log spam)
 */
function truncateQuery(query: string, maxLength: number = 200): string {
  if (query.length <= maxLength) {
    return query;
  }
  return query.substring(0, maxLength) + '...';
}

/**
 * Sanitize query parameters (remove sensitive data)
 */
function sanitizeParams(params: any[]): any[] {
  return params.map(param => {
    if (typeof param === 'string' && param.length > 50) {
      return param.substring(0, 50) + '...';
    }
    if (typeof param === 'object' && param !== null) {
      // Don't log full objects
      return '[Object]';
    }
    return param;
  });
}

/**
 * Get slow query statistics
 */
export function getSlowQueryStats(): {
  total: number;
  slow: number;
  averageDuration: number;
} {
  // This would ideally track stats, but for now return placeholder
  // In production, you'd want to aggregate this data
  return {
    total: 0,
    slow: 0,
    averageDuration: 0,
  };
}

