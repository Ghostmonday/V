/**
 * Connection Pool Monitor
 * Phase 6.2: Monitors database connection pool health
 */

import { logWarning, logError, logInfo } from '../shared/logger.js';
import { alertOnError } from '../middleware/monitoring/error-alerting.js';
import client from 'prom-client';

// Prometheus metrics for connection pool
export const connectionPoolActive = new client.Gauge({
  name: 'db_connection_pool_active',
  help: 'Number of active database connections',
});

export const connectionPoolIdle = new client.Gauge({
  name: 'db_connection_pool_idle',
  help: 'Number of idle database connections',
});

export const connectionPoolTotal = new client.Gauge({
  name: 'db_connection_pool_total',
  help: 'Total number of connections in pool',
});

export const connectionPoolExhausted = new client.Counter({
  name: 'db_connection_pool_exhausted_total',
  help: 'Total number of times connection pool was exhausted',
});

interface PoolStats {
  active: number;
  idle: number;
  total: number;
  max?: number;
}

let lastPoolStats: PoolStats | null = null;
let monitoringInterval: NodeJS.Timeout | null = null;

/**
 * Monitor connection pool (Supabase uses connection pooling internally)
 * Phase 6.2: Track pool health and alert on exhaustion
 */
export function startPoolMonitoring(intervalMs: number = 30000): void {
  if (monitoringInterval) {
    clearInterval(monitoringInterval);
  }

  monitoringInterval = setInterval(async () => {
    try {
      await checkPoolHealth();
    } catch (error: any) {
      logError('Connection pool monitoring error', error);
    }
  }, intervalMs);

  logInfo('Connection pool monitoring started');
}

/**
 * Stop pool monitoring
 */
export function stopPoolMonitoring(): void {
  if (monitoringInterval) {
    clearInterval(monitoringInterval);
    monitoringInterval = null;
    logInfo('Connection pool monitoring stopped');
  }
}

/**
 * Check pool health
 * Note: Supabase doesn't expose direct pool stats, so we infer from query performance
 */
async function checkPoolHealth(): Promise<void> {
  try {
    // For Supabase, we can't directly access pool stats
    // Instead, we monitor query performance and connection errors
    // This is a placeholder - in production, you'd want to:
    // 1. Track query timeouts (indicates pool exhaustion)
    // 2. Monitor connection errors
    // 3. Track active query count

    // For now, update metrics with placeholder values
    // In production, integrate with actual pool monitoring if available
    connectionPoolActive.set(0); // Would be actual active count
    connectionPoolIdle.set(0); // Would be actual idle count
    connectionPoolTotal.set(0); // Would be actual total

    // Check for signs of pool exhaustion
    // This would be detected through:
    // - Query timeouts
    // - Connection errors
    // - Slow queries
  } catch (error: any) {
    logError('Failed to check pool health', error);
  }
}

/**
 * Record pool exhaustion event
 */
export function recordPoolExhaustion(): void {
  connectionPoolExhausted.inc();

  const error = new Error('Database connection pool exhausted');
  alertOnError(error, {
    type: 'db',
    severity: 'critical',
    metadata: {
      event: 'pool_exhaustion',
      timestamp: new Date().toISOString(),
    },
  });

  logError('Connection pool exhausted - critical alert sent', error);
}

/**
 * Get current pool statistics
 */
export function getPoolStats(): PoolStats | null {
  return lastPoolStats;
}
