/**
 * Partition Monitoring Service
 * Phase 9.3: Monitors partition health and provides metrics for dynamic partitioning
 *
 * Features:
 * - Track partition sizes and growth rates
 * - Monitor query performance per partition
 * - Alert on partition issues
 * - Provide metrics for dynamic threshold adjustment
 */

import { supabase } from '../config/db.ts';
import { getRedisClient } from '../config/db.ts';
import { logInfo, logError, logWarning } from '../shared/logger.js';
import { loadPartitionMetadata } from './partition-management-service.js';

const redis = getRedisClient();

// Redis keys for partition metrics
const PARTITION_METRICS_KEY_PREFIX = 'partition_metrics:';
const PARTITION_ALERTS_KEY = 'partition_alerts';

// Thresholds for dynamic partitioning
const DEFAULT_MAX_PARTITION_SIZE_GB = 10; // 10 GB per partition
const DEFAULT_MAX_PARTITION_ROWS = 10_000_000; // 10M rows per partition
const DEFAULT_QUERY_LATENCY_THRESHOLD_MS = 1000; // 1 second

interface PartitionMetrics {
  partitionName: string;
  partitionMonth: string;
  sizeBytes: number;
  sizeGB: number;
  rowCount: number;
  queryCount: number;
  avgQueryLatencyMs: number;
  maxQueryLatencyMs: number;
  lastQueriedAt: string | null;
  isHealthy: boolean;
  alerts: string[];
}

/**
 * Record query metrics for a partition
 * Tracks query performance to inform dynamic partitioning decisions
 *
 * @param partitionMonth - Partition month (YYYY_MM)
 * @param latencyMs - Query latency in milliseconds
 */
export async function recordPartitionQuery(
  partitionMonth: string,
  latencyMs: number
): Promise<void> {
  try {
    const metricsKey = `${PARTITION_METRICS_KEY_PREFIX}${partitionMonth}`;

    // Get existing metrics or create new
    const existing = await redis.get(metricsKey);
    const metrics: Partial<PartitionMetrics> = existing
      ? JSON.parse(existing)
      : {
          partitionMonth,
          queryCount: 0,
          avgQueryLatencyMs: 0,
          maxQueryLatencyMs: 0,
          alerts: [],
        };

    // Update metrics
    metrics.queryCount = (metrics.queryCount || 0) + 1;
    metrics.lastQueriedAt = new Date().toISOString();

    // Update average latency (moving average)
    const currentAvg = metrics.avgQueryLatencyMs || 0;
    const count = metrics.queryCount || 1;
    metrics.avgQueryLatencyMs = (currentAvg * (count - 1) + latencyMs) / count;

    // Update max latency
    if (latencyMs > (metrics.maxQueryLatencyMs || 0)) {
      metrics.maxQueryLatencyMs = latencyMs;
    }

    // Check for performance issues
    if (latencyMs > DEFAULT_QUERY_LATENCY_THRESHOLD_MS) {
      await addPartitionAlert(
        partitionMonth,
        `High query latency: ${latencyMs}ms (threshold: ${DEFAULT_QUERY_LATENCY_THRESHOLD_MS}ms)`
      );
    }

    // Store updated metrics
    await redis.set(metricsKey, JSON.stringify(metrics), 'EX', 86400); // 24 hour TTL
  } catch (error) {
    logError(
      'Failed to record partition query',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Update partition size metrics
 * Called by partition management cron to track partition growth
 *
 * @param partitionMonth - Partition month (YYYY_MM)
 * @param sizeBytes - Partition size in bytes
 * @param rowCount - Number of rows in partition
 */
export async function updatePartitionSize(
  partitionMonth: string,
  sizeBytes: number,
  rowCount: number
): Promise<void> {
  try {
    const metricsKey = `${PARTITION_METRICS_KEY_PREFIX}${partitionMonth}`;

    // Get existing metrics
    const existing = await redis.get(metricsKey);
    const metrics: Partial<PartitionMetrics> = existing
      ? JSON.parse(existing)
      : {
          partitionMonth,
          queryCount: 0,
          avgQueryLatencyMs: 0,
          maxQueryLatencyMs: 0,
          alerts: [],
        };

    // Update size metrics
    metrics.sizeBytes = sizeBytes;
    metrics.sizeGB = sizeBytes / (1024 * 1024 * 1024);
    metrics.rowCount = rowCount;

    // Check for size thresholds
    const maxSizeGB = parseFloat(
      process.env.MAX_PARTITION_SIZE_GB || String(DEFAULT_MAX_PARTITION_SIZE_GB)
    );
    if (metrics.sizeGB > maxSizeGB) {
      await addPartitionAlert(
        partitionMonth,
        `Partition size exceeded: ${metrics.sizeGB.toFixed(2)}GB (threshold: ${maxSizeGB}GB)`
      );
    }

    const maxRows = parseInt(
      process.env.MAX_PARTITION_ROWS || String(DEFAULT_MAX_PARTITION_ROWS),
      10
    );
    if (rowCount > maxRows) {
      await addPartitionAlert(
        partitionMonth,
        `Partition row count exceeded: ${rowCount.toLocaleString()} (threshold: ${maxRows.toLocaleString()})`
      );
    }

    // Determine health status
    metrics.isHealthy = (metrics.alerts || []).length === 0;

    // Store updated metrics
    await redis.set(metricsKey, JSON.stringify(metrics), 'EX', 86400);
  } catch (error) {
    logError(
      'Failed to update partition size',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Add alert for a partition
 */
async function addPartitionAlert(partitionMonth: string, message: string): Promise<void> {
  try {
    const metricsKey = `${PARTITION_METRICS_KEY_PREFIX}${partitionMonth}`;
    const existing = await redis.get(metricsKey);
    const metrics: Partial<PartitionMetrics> = existing
      ? JSON.parse(existing)
      : {
          partitionMonth,
          alerts: [],
        };

    if (!metrics.alerts) {
      metrics.alerts = [];
    }

    // Add alert if not already present
    if (!metrics.alerts.includes(message)) {
      metrics.alerts.push(message);
      metrics.isHealthy = false;

      await redis.set(metricsKey, JSON.stringify(metrics), 'EX', 86400);

      // Also store in alerts list
      const alert = {
        partitionMonth,
        message,
        timestamp: new Date().toISOString(),
      };

      await redis.lpush(PARTITION_ALERTS_KEY, JSON.stringify(alert));
      await redis.ltrim(PARTITION_ALERTS_KEY, 0, 999); // Keep last 1000 alerts

      logWarning('Partition alert', alert);
    }
  } catch (error) {
    logError(
      'Failed to add partition alert',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Get partition metrics for all partitions
 * Loads metrics from Redis and enriches with database metadata
 */
export async function getAllPartitionMetrics(): Promise<PartitionMetrics[]> {
  try {
    // Load partition metadata from database
    const partitions = await loadPartitionMetadata();

    // Enrich with Redis metrics
    const metrics: PartitionMetrics[] = [];

    for (const partition of partitions) {
      const metricsKey = `${PARTITION_METRICS_KEY_PREFIX}${partition.partition_month}`;
      const cached = await redis.get(metricsKey);

      const partitionMetrics: PartitionMetrics = {
        partitionName: partition.partition_name,
        partitionMonth: partition.partition_month,
        sizeBytes: partition.size_bytes || 0,
        sizeGB: (partition.size_bytes || 0) / (1024 * 1024 * 1024),
        rowCount: partition.row_count || 0,
        queryCount: 0,
        avgQueryLatencyMs: 0,
        maxQueryLatencyMs: 0,
        lastQueriedAt: null,
        isHealthy: true,
        alerts: [],
      };

      if (cached) {
        const cachedMetrics = JSON.parse(cached);
        partitionMetrics.queryCount = cachedMetrics.queryCount || 0;
        partitionMetrics.avgQueryLatencyMs = cachedMetrics.avgQueryLatencyMs || 0;
        partitionMetrics.maxQueryLatencyMs = cachedMetrics.maxQueryLatencyMs || 0;
        partitionMetrics.lastQueriedAt = cachedMetrics.lastQueriedAt || null;
        partitionMetrics.alerts = cachedMetrics.alerts || [];
        partitionMetrics.isHealthy = cachedMetrics.isHealthy !== false;
      }

      metrics.push(partitionMetrics);
    }

    return metrics;
  } catch (error) {
    logError(
      'Failed to get partition metrics',
      error instanceof Error ? error : new Error(String(error))
    );
    return [];
  }
}

/**
 * Get partition health summary
 * Returns overall health status and alerts
 */
export async function getPartitionHealthSummary(): Promise<{
  totalPartitions: number;
  healthyPartitions: number;
  unhealthyPartitions: number;
  totalAlerts: number;
  recentAlerts: Array<{ partitionMonth: string; message: string; timestamp: string }>;
}> {
  try {
    const metrics = await getAllPartitionMetrics();

    const healthy = metrics.filter((m) => m.isHealthy).length;
    const unhealthy = metrics.length - healthy;

    // Get recent alerts
    const alertsData = await redis.lrange(PARTITION_ALERTS_KEY, 0, 99); // Last 100 alerts
    const recentAlerts = alertsData.map((a: string) => JSON.parse(a));

    return {
      totalPartitions: metrics.length,
      healthyPartitions: healthy,
      unhealthyPartitions: unhealthy,
      totalAlerts: metrics.reduce((sum, m) => sum + m.alerts.length, 0),
      recentAlerts,
    };
  } catch (error) {
    logError(
      'Failed to get partition health summary',
      error instanceof Error ? error : new Error(String(error))
    );
    return {
      totalPartitions: 0,
      healthyPartitions: 0,
      unhealthyPartitions: 0,
      totalAlerts: 0,
      recentAlerts: [],
    };
  }
}

/**
 * Calculate dynamic partition threshold based on load
 * Adjusts thresholds based on current system load and partition performance
 *
 * @returns Dynamic threshold configuration
 */
export async function calculateDynamicThresholds(): Promise<{
  maxPartitionSizeGB: number;
  maxPartitionRows: number;
  queryLatencyThresholdMs: number;
  shouldCreatePartition: boolean;
}> {
  try {
    const metrics = await getAllPartitionMetrics();

    if (metrics.length === 0) {
      // Default thresholds if no partitions
      return {
        maxPartitionSizeGB: DEFAULT_MAX_PARTITION_SIZE_GB,
        maxPartitionRows: DEFAULT_MAX_PARTITION_ROWS,
        queryLatencyThresholdMs: DEFAULT_QUERY_LATENCY_THRESHOLD_MS,
        shouldCreatePartition: false,
      };
    }

    // Calculate average metrics
    const avgSizeGB = metrics.reduce((sum, m) => sum + m.sizeGB, 0) / metrics.length;
    const avgRowCount = metrics.reduce((sum, m) => sum + m.rowCount, 0) / metrics.length;
    const avgLatency = metrics.reduce((sum, m) => sum + m.avgQueryLatencyMs, 0) / metrics.length;

    // Adjust thresholds based on performance
    // If average latency is high, reduce partition size threshold
    let maxPartitionSizeGB = DEFAULT_MAX_PARTITION_SIZE_GB;
    if (avgLatency > DEFAULT_QUERY_LATENCY_THRESHOLD_MS * 0.8) {
      // Reduce threshold by 20% if approaching latency limit
      maxPartitionSizeGB = DEFAULT_MAX_PARTITION_SIZE_GB * 0.8;
    }

    // If partitions are growing fast, consider creating new partition earlier
    const shouldCreatePartition = metrics.some(
      (m) => m.sizeGB > maxPartitionSizeGB * 0.8 || m.rowCount > DEFAULT_MAX_PARTITION_ROWS * 0.8
    );

    return {
      maxPartitionSizeGB,
      maxPartitionRows: DEFAULT_MAX_PARTITION_ROWS,
      queryLatencyThresholdMs: DEFAULT_QUERY_LATENCY_THRESHOLD_MS,
      shouldCreatePartition,
    };
  } catch (error) {
    logError(
      'Failed to calculate dynamic thresholds',
      error instanceof Error ? error : new Error(String(error))
    );
    return {
      maxPartitionSizeGB: DEFAULT_MAX_PARTITION_SIZE_GB,
      maxPartitionRows: DEFAULT_MAX_PARTITION_ROWS,
      queryLatencyThresholdMs: DEFAULT_QUERY_LATENCY_THRESHOLD_MS,
      shouldCreatePartition: false,
    };
  }
}

/**
 * Clear partition alerts
 * Removes alerts for a specific partition or all partitions
 *
 * @param partitionMonth - Partition month (optional, clears all if not provided)
 */
export async function clearPartitionAlerts(partitionMonth?: string): Promise<void> {
  try {
    if (partitionMonth) {
      const metricsKey = `${PARTITION_METRICS_KEY_PREFIX}${partitionMonth}`;
      const existing = await redis.get(metricsKey);
      if (existing) {
        const metrics = JSON.parse(existing);
        metrics.alerts = [];
        metrics.isHealthy = true;
        await redis.set(metricsKey, JSON.stringify(metrics), 'EX', 86400);
      }
    } else {
      // Clear all alerts
      await redis.del(PARTITION_ALERTS_KEY);
    }

    logInfo('Cleared partition alerts', { partitionMonth: partitionMonth || 'all' });
  } catch (error) {
    logError(
      'Failed to clear partition alerts',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}
