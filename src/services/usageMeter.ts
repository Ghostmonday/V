/**
 * Usage Metering Service
 * Tracks and enforces usage quotas for AI calls, voice minutes, and storage
 */

import { supabase } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';

/**
 * Increment usage for a user
 * @param userId - User ID
 * @param type - Usage type: 'ai_calls', 'voice_minutes', or 'storage_bytes'
 * @param amount - Amount to increment (default: 1 for calls/minutes, bytes for storage)
 */
export async function incrementUsage(
  userId: string,
  type: 'ai_calls' | 'voice_minutes' | 'storage_bytes',
  amount: number = 1
): Promise<void> {
  try {
    // Use the database function to get or create usage record
    const { data: usageData, error: fetchError } = await supabase
      .rpc('get_or_create_usage', {
        p_user_id: userId,
        p_period_start: new Date().toISOString().slice(0, 7) + '-01T00:00:00Z' // First day of current month
      });

    if (fetchError) {
      throw fetchError;
    }

    const usageId = usageData;

    // Increment the appropriate field using the database function
    const { error: incrementError } = await supabase
      .rpc('increment_usage', {
        p_user_id: userId,
        p_type: type,
        p_amount: amount
      });

    if (incrementError) {
      throw incrementError;
    }

    logInfo(`Incremented ${type} for user ${userId}: +${amount}`);
  } catch (error) {
    logError(`Failed to increment usage (${type})`, error instanceof Error ? error : new Error(String(error)));
    throw error;
  }
}

/**
 * Check if user is within quota
 * @param userId - User ID
 * @param type - Usage type to check
 * @param limit - Maximum allowed usage
 * @returns true if within quota, false if exceeded
 */
export async function checkQuota(
  userId: string,
  type: 'ai_calls' | 'voice_minutes' | 'storage_bytes',
  limit: number
): Promise<boolean> {
  try {
    const currentMonth = new Date().toISOString().slice(0, 7) + '-01T00:00:00Z';
    
    const { data, error } = await supabase
      .from('usage')
      .select(type)
      .eq('user_id', userId)
      .eq('period_start', currentMonth)
      .single();

    if (error && error.code !== 'PGRST116') { // PGRST116 = no rows returned
      throw error;
    }

    const currentUsage = data?.[type] || 0;
    const withinQuota = currentUsage < limit;

    if (!withinQuota) {
      logInfo(`Quota exceeded for user ${userId}: ${type} = ${currentUsage}/${limit}`);
    }

    return withinQuota;
  } catch (error) {
    logError(`Failed to check quota (${type})`, error instanceof Error ? error : new Error(String(error)));
    // Fail open - allow usage if check fails (prevents blocking users due to DB issues)
    return true;
  }
}

/**
 * Get current usage for a user
 * @param userId - User ID
 * @returns Current usage stats for the current period
 */
export async function getUsage(userId: string): Promise<{
  ai_calls: number;
  voice_minutes: number;
  storage_bytes: number;
  period_start: string;
  period_end: string;
}> {
  try {
    const currentMonth = new Date().toISOString().slice(0, 7) + '-01T00:00:00Z';
    
    const { data, error } = await supabase
      .from('usage')
      .select('*')
      .eq('user_id', userId)
      .eq('period_start', currentMonth)
      .single();

    if (error && error.code !== 'PGRST116') {
      throw error;
    }

    return data || {
      ai_calls: 0,
      voice_minutes: 0,
      storage_bytes: 0,
      period_start: currentMonth,
      period_end: new Date(new Date(currentMonth).setMonth(new Date(currentMonth).getMonth() + 1)).toISOString()
    };
  } catch (error) {
    logError('Failed to get usage', error instanceof Error ? error : new Error(String(error)));
    throw error;
  }
}

