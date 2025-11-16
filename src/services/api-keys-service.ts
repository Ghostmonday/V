/**
 * API Keys Service
 * Retrieves encrypted API keys from database
 * Replaces hardcoded environment variables
 */

import { supabase } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';

// Cache for keys (to avoid repeated DB calls)
const keyCache = new Map<string, { value: string; expiresAt: number }>();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

/**
 * Get an API key from the database vault
 * @param keyName - Name of the key (e.g., 'APPLE_TEAM_ID')
 * @param environment - Environment (default: 'production')
 * @returns Decrypted key value
 */
export async function getApiKey(
  keyName: string,
  environment: string = 'production'
): Promise<string> {
  // Check cache first
  const cacheKey = `${keyName}:${environment}`;
  const cached = keyCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.value;
  }

  try {
    // Call the database function to retrieve and decrypt the key
    const { data, error } = await supabase.rpc('get_api_key', {
      p_key_name: keyName,
      p_environment: environment,
    });

    if (error) {
      logError(`Failed to retrieve API key: ${keyName}`, error);
      throw new Error(`API key not found: ${keyName}`);
    }

    if (!data) {
      throw new Error(`API key not found: ${keyName}`);
    }

    // Cache the value
    keyCache.set(cacheKey, {
      value: data,
      expiresAt: Date.now() + CACHE_TTL,
    });

    return data;
  } catch (error) {
    logError(`Error retrieving API key: ${keyName}`, error);
    throw error;
  }
}

/**
 * Get multiple API keys by category
 * @param category - Category name (e.g., 'apple', 'livekit')
 * @param environment - Environment (default: 'production')
 * @returns Object with key names as properties
 */
export async function getApiKeysByCategory(
  category: string,
  environment: string = 'production'
): Promise<Record<string, string>> {
  try {
    const { data, error } = await supabase.rpc('get_api_keys_by_category', {
      p_category: category,
      p_environment: environment,
    });

    if (error) {
      logError(`Failed to retrieve API keys for category: ${category}`, error);
      throw new Error(`Failed to retrieve keys for category: ${category}`);
    }

    // Convert array to object
    // Handle both old format (key_name) and new format (result_key_name)
    const result: Record<string, string> = {};
    if (data && Array.isArray(data)) {
      for (const item of data) {
        const keyName = item.result_key_name || item.key_name;
        const keyValue = item.result_key_value || item.key_value;
        result[keyName] = keyValue;
      }
    }

    return result;
  } catch (error) {
    logError(`Error retrieving API keys by category: ${category}`, error);
    throw error;
  }
}

/**
 * Convenience functions for specific key categories
 */

export async function getAppleKeys(): Promise<{
  teamId: string;
  serviceId: string;
  keyId: string;
  privateKey: string;
  clientId: string;
}> {
  const keys = await getApiKeysByCategory('apple');
  return {
    teamId: keys.APPLE_TEAM_ID || '',
    serviceId: keys.APPLE_SERVICE_ID || '',
    keyId: keys.APPLE_KEY_ID || '',
    privateKey: keys.APPLE_PRIVATE_KEY || '',
    clientId: keys.APPLE_CLIENT_ID || '',
  };
}

export async function getLiveKitKeys(): Promise<{
  apiKey: string;
  apiSecret: string;
  url: string;
  host: string;
}> {
  const keys = await getApiKeysByCategory('livekit');
  return {
    apiKey: keys.LIVEKIT_API_KEY || '',
    apiSecret: keys.LIVEKIT_API_SECRET || '',
    url: keys.LIVEKIT_URL || '',
    host: keys.LIVEKIT_HOST || '',
  };
}

export async function getSupabaseKeys(): Promise<{
  url: string;
  serviceRoleKey: string;
  anonKey: string;
}> {
  const keys = await getApiKeysByCategory('supabase');
  return {
    url: keys.NEXT_PUBLIC_SUPABASE_URL || '',
    serviceRoleKey: keys.SUPABASE_SERVICE_ROLE_KEY || '',
    anonKey: keys.SUPABASE_ANON_KEY || '',
  };
}

export async function getJwtSecret(): Promise<string> {
  return await getApiKey('JWT_SECRET');
}

export async function getDeepSeekKey(): Promise<string> {
  return await getApiKey('DEEPSEEK_API_KEY');
}

export async function getGrokKey(): Promise<string> {
  return await getApiKey('GROK_API_KEY');
}

export async function getOpenAIKey(): Promise<string> {
  return await getApiKey('OPENAI_KEY');
}

export async function getAwsKeys(): Promise<{
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  region: string;
}> {
  const keys = await getApiKeysByCategory('aws');
  return {
    accessKeyId: keys.AWS_ACCESS_KEY_ID || '',
    secretAccessKey: keys.AWS_SECRET_ACCESS_KEY || '',
    bucket: keys.AWS_S3_BUCKET || '',
    region: keys.AWS_REGION || '',
  };
}

export async function getAppleSharedSecret(): Promise<string> {
  return await getApiKey('APPLE_SHARED_SECRET');
}

export async function getRedisUrl(): Promise<string> {
  try {
    return await getApiKey('REDIS_URL', 'production');
  } catch {
    // Fallback: Redis URL can stay in env for local dev (performance blocker for vault)
    // TODO: Move to vault when performance allows
    return process.env.REDIS_URL || 'redis://localhost:6379';
  }
}

/**
 * Clear the key cache (useful after key updates)
 */
export function clearKeyCache(): void {
  keyCache.clear();
  logInfo('API key cache cleared');
}

/**
 * Initialize: Pre-load commonly used keys
 */
export async function initializeApiKeys(): Promise<void> {
  try {
    // Pre-load critical keys
    await Promise.all([
      getJwtSecret().catch(() => null),
      getAppleKeys().catch(() => null),
      getLiveKitKeys().catch(() => null),
    ]);
    logInfo('API keys service initialized');
  } catch (error) {
    logError('Failed to initialize API keys', error);
  }
}

