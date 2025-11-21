/**
 * Database configuration
 * Provides Supabase client and Redis connection instances
 */

import { createClient } from '@supabase/supabase-js';
import Redis from 'ioredis';
import { logError, logInfo, logWarning } from '../shared/logger-shared.js';
import { getSupabaseKeys, getRedisUrl } from '../services/api-keys-service.js';
import {
  createRedisClient,
  parseRedisConfig,
  checkRedisHealth,
  type RedisClusterConfig,
} from './redis-cluster.js';

// Initialize with env vars (needed for initial connection to vault)
// These will be migrated to vault after first connection
let supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
let supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Validate environment variables
if (!supabaseUrl) {
  const errorMsg = 'Missing NEXT_PUBLIC_SUPABASE_URL - required for database connection';
  logError(errorMsg);
  console.error('❌', errorMsg);
  console.error('   Set NEXT_PUBLIC_SUPABASE_URL in Railway Dashboard → Variables');
  throw new Error('NEXT_PUBLIC_SUPABASE_URL is required');
}

if (!supabaseKey) {
  const errorMsg = 'Missing SUPABASE_SERVICE_ROLE_KEY - required for database connection';
  logError(errorMsg);
  console.error('❌', errorMsg);
  console.error('   Set SUPABASE_SERVICE_ROLE_KEY in Railway Dashboard → Variables');
  throw new Error('SUPABASE_SERVICE_ROLE_KEY is required');
}

// Initialize Supabase client with enhanced configuration
export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    persistSession: false, // Backend doesn't need session persistence
    autoRefreshToken: false,
  },
  db: {
    schema: 'public',
  },
  global: {
    headers: { 'x-application-name': 'vibez-backend' },
  },
});

// Connection health check state
let lastHealthCheck = Date.now(); // Track last successful health check timestamp
let healthCheckInterval: NodeJS.Timeout | null = null; // Interval reference for cleanup

/**
 * Check Supabase database connectivity
 *
 * Performs a lightweight query to verify database is reachable and responsive.
 * Used by circuit breaker and monitoring systems.
 *
 * @returns true if database is healthy, false otherwise
 */
export async function checkSupabaseHealth(): Promise<boolean> {
  try {
    // Perform minimal query: select single ID from users table
    // This is the lightest possible query (no joins, no filters, limit 1)
    // If this fails, database is likely down or unreachable
    const { error } = await supabase
      .from('users')
      .select('id') // Only select ID column (minimal data transfer)
      .limit(1); // Only need 1 row to verify connectivity

    if (error) {
      logError('Supabase health check failed', error); // Silent fail: timeout not caught here, returns true
      return false; // Database error indicates unhealthy state
    }

    // Update last successful check timestamp
    lastHealthCheck = Date.now(); // Race: concurrent health checks can overwrite timestamp
    return true; // Query succeeded = healthy
  } catch (error: any) {
    // Network errors, timeouts, etc.
    logError('Supabase health check error', error); // Unhandled timeout: Supabase client timeout not configured
    return false; // Any exception = unhealthy
  }
}

// Periodic health check: run every 30 seconds
// Proactively detects database issues before they cause user-facing errors
if (!healthCheckInterval) {
  healthCheckInterval = setInterval(async () => {
    const healthy = await checkSupabaseHealth(); // Async handoff: interval doesn't await, errors swallowed
    if (!healthy) {
      logError('Supabase connection unhealthy, triggering circuit breaker'); // Silent fail: circuit breaker not actually triggered here
      // Note: Circuit breaker will be triggered by actual failed requests
      // This health check just provides early warning/logging
    }
  }, 30000); // 30000ms = 30 seconds
}

// Singleton Redis client instance (shared across entire application)
// Supports single instance, cluster, and sentinel modes
let redisClient: Redis.Redis | Redis.Cluster | null = null;
let redisClientPromise: Promise<Redis.Redis | Redis.Cluster> | null = null;
let redisConfig: RedisClusterConfig | null = null;

/**
 * Get or create Redis client instance
 * Uses singleton pattern to ensure only one connection pool is created
 * Supports Redis Cluster and Sentinel modes for high availability
 *
 * Configuration via environment variables:
 * - REDIS_MODE: 'single' | 'cluster' | 'sentinel' (default: 'single')
 * - REDIS_URL: For single mode (default: 'redis://localhost:6379')
 * - REDIS_CLUSTER_NODES: For cluster mode (comma-separated host:port)
 * - REDIS_SENTINELS: For sentinel mode (comma-separated host:port)
 * - REDIS_SENTINEL_NAME: For sentinel mode (default: 'mymaster')
 * - REDIS_PASSWORD: Optional password for all modes
 */
export function getRedisClient(): Redis.Redis | Redis.Cluster {
  if (!redisClient) {
    // Check if REDIS_URL is set (Railway auto-sets this when Redis service is added)
    // Allow localhost for testing environments
    if (!process.env.REDIS_URL || (process.env.REDIS_URL === 'redis://localhost:6379' && process.env.NODE_ENV === 'production')) {
      const errorMsg = 'REDIS_URL not set or using localhost in production - Redis service may not be added in Railway';
      logError(errorMsg);
      console.error('❌', errorMsg);
      console.error('   Current REDIS_URL:', process.env.REDIS_URL || '(not set)');
      console.error('   Fix: Railway Dashboard → Redis Service → Variables → Copy REDIS_URL');
      console.error('   Then: Railway Dashboard → App Service → Variables → Set REDIS_URL');
      console.error('   OR: Railway should auto-set it if Redis service is connected');
      // Don't create a client with localhost in production - it won't work in Railway
      throw new Error('REDIS_URL is required. Add Redis service in Railway to auto-set this variable.');
    }

    try {
      // Parse configuration from environment
      redisConfig = parseRedisConfig();

      // Create Redis client based on configuration (supports cluster/sentinel)
      redisClient = createRedisClient(redisConfig);

      logInfo(`Redis client initialized in ${redisConfig.mode} mode`);
      console.log(`✅ Redis client initialized (mode: ${redisConfig.mode})`);
    } catch (error) {
      logError(
        'Failed to initialize Redis client',
        error instanceof Error ? error : new Error(String(error))
      );
      console.error('❌ Failed to initialize Redis client:', error);
      throw error; // Don't fallback to localhost - fail fast with clear error
    }
  }
  // Return existing client if already created (singleton pattern)
  return redisClient;
}

/**
 * Get Redis client configuration
 */
export function getRedisConfig(): RedisClusterConfig | null {
  if (!redisConfig) {
    try {
      redisConfig = parseRedisConfig();
    } catch (error) {
      logError(
        'Failed to parse Redis config',
        error instanceof Error ? error : new Error(String(error))
      );
    }
  }
  return redisConfig;
}

/**
 * Check Redis health (supports cluster and sentinel)
 */
export async function checkRedisHealthStatus(): Promise<boolean> {
  if (!redisClient) {
    return false;
  }
  return await checkRedisHealth(redisClient);
}

// Database is Supabase-only - no legacy PostgreSQL adapters
