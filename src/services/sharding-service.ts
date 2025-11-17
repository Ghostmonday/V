/**
 * Database Sharding Service
 * Phase 9.1: Implements sharding strategy for horizontal scaling
 * 
 * Sharding Strategy:
 * - Shard key: room_id (messages are primarily queried by room)
 * - Distribution: Consistent hashing using room_id UUID
 * - Cross-shard queries: Handled via aggregation service
 * 
 * Architecture:
 * - Shard routing: Determines which shard to query based on room_id
 * - Cross-shard queries: Aggregates results from multiple shards
 * - Shard health: Monitors shard availability and performance
 */

import { logInfo, logError, logWarning } from '../shared/logger.js';
import { supabase } from '../config/db.ts';
import { getRedisClient } from '../config/db.ts';

const redis = getRedisClient();

// Shard configuration
interface ShardConfig {
  shardId: string;
  databaseUrl: string;
  isActive: boolean;
  weight: number; // For weighted distribution
  metadata?: Record<string, any>;
}

// Default shard (current database)
const DEFAULT_SHARD_ID = 'shard_0';

// Shard registry stored in Redis and system_config table
const SHARD_REGISTRY_KEY = 'shard_registry';
const SHARD_HEALTH_KEY_PREFIX = 'shard_health:';

/**
 * Get shard ID for a given room_id
 * Uses consistent hashing to ensure same room always routes to same shard
 * 
 * @param roomId - Room UUID
 * @returns Shard ID
 */
export function getShardForRoom(roomId: string): string {
  // For now, use simple modulo hashing
  // In production, use consistent hashing (e.g., ketama) for better distribution
  const hash = hashString(roomId);
  const shardCount = getShardCount();
  
  // If only one shard, return default
  if (shardCount <= 1) {
    return DEFAULT_SHARD_ID;
  }
  
  const shardIndex = hash % shardCount;
  return `shard_${shardIndex}`;
}

/**
 * Simple string hash function
 * Uses djb2 algorithm for consistent hashing
 */
function hashString(str: string): number {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) + hash) + str.charCodeAt(i);
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash);
}

/**
 * Get total number of active shards
 */
function getShardCount(): number {
  // Check environment variable first
  const envShardCount = parseInt(process.env.SHARD_COUNT || '1', 10);
  if (envShardCount > 1) {
    return envShardCount;
  }
  
  // Default to single shard (no sharding)
  return 1;
}

/**
 * Register a shard configuration
 * Stores shard metadata in Redis and database
 * 
 * @param shardConfig - Shard configuration
 */
export async function registerShard(shardConfig: ShardConfig): Promise<void> {
  try {
    // Store in Redis for fast access
    const registry = await getShardRegistry();
    registry[shardConfig.shardId] = shardConfig;
    
    await redis.set(
      SHARD_REGISTRY_KEY,
      JSON.stringify(registry),
      'EX',
      3600 // 1 hour TTL
    );
    
    // Also store in database for persistence
    const { error } = await supabase
      .from('system_config')
      .upsert({
        key: `shard_config:${shardConfig.shardId}`,
        value: shardConfig,
        updated_at: new Date().toISOString()
      });
    
    if (error) {
      logError('Failed to store shard config in database', error);
    }
    
    logInfo('Shard registered', { shardId: shardConfig.shardId });
  } catch (error) {
    logError('Failed to register shard', error instanceof Error ? error : new Error(String(error)));
    throw error;
  }
}

/**
 * Get shard registry from Redis or database
 */
async function getShardRegistry(): Promise<Record<string, ShardConfig>> {
  try {
    // Try Redis first
    const cached = await redis.get(SHARD_REGISTRY_KEY);
    if (cached) {
      return JSON.parse(cached);
    }
    
    // Fallback to database
    const { data, error } = await supabase
      .from('system_config')
      .select('key, value')
      .like('key', 'shard_config:%');
    
    if (error || !data) {
      logWarning('Failed to load shard registry from database', { error });
      return {};
    }
    
    const registry: Record<string, ShardConfig> = {};
    for (const item of data) {
      const shardId = item.key.replace('shard_config:', '');
      registry[shardId] = item.value as ShardConfig;
    }
    
    // Cache in Redis
    await redis.set(
      SHARD_REGISTRY_KEY,
      JSON.stringify(registry),
      'EX',
      3600
    );
    
    return registry;
  } catch (error) {
    logError('Failed to get shard registry', error instanceof Error ? error : new Error(String(error)));
    return {};
  }
}

/**
 * Get shard configuration for a specific shard
 */
export async function getShardConfig(shardId: string): Promise<ShardConfig | null> {
  const registry = await getShardRegistry();
  return registry[shardId] || null;
}

/**
 * Route query to appropriate shard(s)
 * For single-room queries, routes to one shard
 * For cross-shard queries, returns list of shards to query
 * 
 * @param roomIds - Array of room IDs (empty array means all shards)
 * @returns Array of shard IDs to query
 */
export function routeToShards(roomIds: string[]): string[] {
  if (roomIds.length === 0) {
    // Query all shards for cross-shard operations
    const shardCount = getShardCount();
    return Array.from({ length: shardCount }, (_, i) => `shard_${i}`);
  }
  
  // Get unique shards for the given rooms
  const shardSet = new Set<string>();
  for (const roomId of roomIds) {
    const shardId = getShardForRoom(roomId);
    shardSet.add(shardId);
  }
  
  return Array.from(shardSet);
}

/**
 * Record shard health metrics
 * Tracks query latency, error rates, and availability
 * 
 * @param shardId - Shard ID
 * @param metrics - Health metrics
 */
export async function recordShardHealth(
  shardId: string,
  metrics: {
    latencyMs: number;
    errorCount: number;
    queryCount: number;
    isHealthy: boolean;
  }
): Promise<void> {
  try {
    const healthKey = `${SHARD_HEALTH_KEY_PREFIX}${shardId}`;
    const healthData = {
      shardId,
      timestamp: Date.now(),
      ...metrics,
      errorRate: metrics.queryCount > 0 ? metrics.errorCount / metrics.queryCount : 0
    };
    
    // Store in Redis with 1 hour TTL
    await redis.set(
      healthKey,
      JSON.stringify(healthData),
      'EX',
      3600
    );
    
    // Also log to telemetry
    await supabase.from('telemetry').insert({
      event: 'shard_health',
      features: healthData,
      latency_ms: metrics.latencyMs
    });
  } catch (error) {
    logError('Failed to record shard health', error instanceof Error ? error : new Error(String(error)));
  }
}

/**
 * Get shard health status
 * Returns health metrics for all shards
 */
export async function getShardHealth(): Promise<Record<string, any>> {
  try {
    const shardCount = getShardCount();
    const health: Record<string, any> = {};
    
    for (let i = 0; i < shardCount; i++) {
      const shardId = `shard_${i}`;
      const healthKey = `${SHARD_HEALTH_KEY_PREFIX}${shardId}`;
      const healthData = await redis.get(healthKey);
      
      if (healthData) {
        health[shardId] = JSON.parse(healthData);
      } else {
        health[shardId] = {
          shardId,
          isHealthy: true, // Assume healthy if no data
          timestamp: null
        };
      }
    }
    
    return health;
  } catch (error) {
    logError('Failed to get shard health', error instanceof Error ? error : new Error(String(error)));
    return {};
  }
}

/**
 * Check if sharding is enabled
 */
export function isShardingEnabled(): boolean {
  return getShardCount() > 1;
}

/**
 * Execute query on specific shard
 * In production, this would route to the actual shard database
 * For now, it's a placeholder that routes to default database
 * 
 * @param shardId - Shard ID
 * @param queryFn - Query function to execute
 */
export async function executeOnShard<T>(
  shardId: string,
  queryFn: () => Promise<T>
): Promise<T> {
  // If sharding not enabled, execute on default database
  if (!isShardingEnabled() || shardId === DEFAULT_SHARD_ID) {
    return await queryFn();
  }
  
  // TODO: In production, route to actual shard database
  // For now, log that we would route to shard
  logInfo('Routing query to shard', { shardId });
  
  // Execute query (currently routes to default database)
  // In production, this would use shard-specific database connection
  return await queryFn();
}

/**
 * Execute query across multiple shards and aggregate results
 * Used for cross-shard queries (e.g., user's messages across all rooms)
 * 
 * @param shardIds - Array of shard IDs to query
 * @param queryFn - Query function to execute on each shard
 * @param aggregateFn - Function to aggregate results from all shards
 */
export async function executeCrossShard<T, R>(
  shardIds: string[],
  queryFn: (shardId: string) => Promise<T>,
  aggregateFn: (results: T[]) => R
): Promise<R> {
  const results = await Promise.all(
    shardIds.map(shardId => executeOnShard(shardId, () => queryFn(shardId)))
  );
  
  return aggregateFn(results);
}

