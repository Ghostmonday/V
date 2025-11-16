/**
 * Database configuration
 * Provides Supabase client and Redis connection instances
 */

import { createClient } from '@supabase/supabase-js';
import Redis from 'ioredis';
import { logError, logInfo } from '../shared/logger.js';
import { getSupabaseKeys, getRedisUrl } from '../services/api-keys-service.js';

// Initialize with env vars (needed for initial connection to vault)
// These will be migrated to vault after first connection
let supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
let supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Validate environment variables
if (!supabaseUrl) {
  logError('Missing NEXT_PUBLIC_SUPABASE_URL in .env file');
  throw new Error('NEXT_PUBLIC_SUPABASE_URL is required');
}

if (!supabaseKey) {
  logError('Missing SUPABASE_SERVICE_ROLE_KEY in .env file');
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
let redisClient: Redis | null = null;
let redisClientPromise: Promise<Redis> | null = null;

/**
 * Get or create Redis client instance
 * Uses singleton pattern to ensure only one connection pool is created
 * NOTE: Redis URL stays in env for now (vault not feasible: performance blocker)
 * TODO: Move to vault when async initialization performance allows
 */
export function getRedisClient(): Redis {
  if (!redisClient) {
    // VAULT NOT FEASIBLE: Performance blocker - Redis needed synchronously at startup
    // This must be available immediately, can't wait for async vault call
    const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
    
    // Create Redis client with retry configuration
    redisClient = new Redis(redisUrl, {
      retryStrategy: (times) => {
        // Exponential backoff with cap: 50ms, 100ms, 150ms... up to 2000ms max
        // times = number of retry attempts (1, 2, 3, ...)
        // Math.min ensures delay never exceeds 2000ms (2 seconds)
        const delay = Math.min(times * 50, 2000);
        return delay; // Return delay in milliseconds, or null/undefined to stop retrying
      },
      maxRetriesPerRequest: 3, // Max 3 retries per command before giving up
    });

    // Error handler: log but don't crash (Redis failures are non-fatal)
    redisClient.on('error', (err) => {
      logError('Redis connection error', err);
      // Note: Errors are logged but app continues (graceful degradation)
    });

    // Connection success handler
    redisClient.on('connect', () => {
      logInfo('Redis connected');
    });
  }
  // Return existing client if already created (singleton pattern)
  return redisClient;
}

// Database is Supabase-only - no legacy PostgreSQL adapters

