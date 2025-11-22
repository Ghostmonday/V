/**
 * Redis JSON Helper
 * Provides Redis JSON commands support using ioredis
 * 
 * Note: Redis JSON requires Redis 7.0+ with JSON module enabled
 * Railway Redis should support this by default
 */

import { getRedisClient } from '../config/database-config.js';
import { logError } from '../shared/logger-shared.js';

const redis = getRedisClient();

/**
 * Set JSON data in Redis
 * Equivalent to: JSON.SET key $ value
 * 
 * @param key Redis key
 * @param value JSON-serializable value
 * @param path JSONPath (default: '$' for root)
 * @returns true if successful
 */
export async function redisJsonSet<T>(
  key: string,
  value: T,
  path: string = '$'
): Promise<boolean> {
  try {
    // ioredis supports Redis JSON commands via call() method
    // JSON.SET key path value
    await redis.call('JSON.SET', key, path, JSON.stringify(value));
    return true;
  } catch (error) {
    logError('Redis JSON.SET failed', error instanceof Error ? error : new Error(String(error)));
    return false;
  }
}

/**
 * Get JSON data from Redis
 * Equivalent to: JSON.GET key path
 * 
 * @param key Redis key
 * @param path JSONPath (default: '$' for root)
 * @returns Parsed JSON value or null
 */
export async function redisJsonGet<T>(
  key: string,
  path: string = '$'
): Promise<T | null> {
  try {
    // JSON.GET key path
    const result = await redis.call('JSON.GET', key, path) as string | null;
    if (!result) return null;
    
    // Parse JSON string
    const parsed = JSON.parse(result);
    
    // If path is '$', result is wrapped in array, extract first element
    if (path === '$' && Array.isArray(parsed) && parsed.length > 0) {
      return parsed[0] as T;
    }
    
    return parsed as T;
  } catch (error) {
    logError('Redis JSON.GET failed', error instanceof Error ? error : new Error(String(error)));
    return null;
  }
}

/**
 * Delete JSON key
 * Equivalent to: DEL key
 */
export async function redisJsonDel(key: string): Promise<boolean> {
  try {
    await redis.del(key);
    return true;
  } catch (error) {
    logError('Redis JSON.DEL failed', error instanceof Error ? error : new Error(String(error)));
    return false;
  }
}

/**
 * Example usage (matching your code):
 * 
 * ```typescript
 * import { redisJsonSet, redisJsonGet } from './utils/redis-json-helper.js';
 * 
 * // Set JSON data
 * await redisJsonSet('user:1', {
 *   name: 'Alice',
 *   emails: ['alice@example.com', 'alice@work.com'],
 *   address: { city: 'NYC', zip: '10001' }
 * });
 * 
 * // Get entire object
 * const user = await redisJsonGet('user:1'); // { name: 'Alice', emails: [...], address: {...} }
 * 
 * // Get specific field (requires JSONPath)
 * const name = await redisJsonGet<string>('user:1', '$.name'); // "Alice"
 * const email = await redisJsonGet<string>('user:1', '$.emails[0]'); // "alice@example.com"
 * const zip = await redisJsonGet<string>('user:1', '$.address.zip'); // "10001"
 * ```
 */



