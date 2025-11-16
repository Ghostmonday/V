/**
 * Bandwidth Service
 * Handles low-bandwidth mode preferences and media downsampling
 */

import { supabase } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';

/**
 * Get user bandwidth preference
 */
export async function getBandwidthMode(userId: string): Promise<'auto' | 'low' | 'high'> {
  try {
    const { data } = await supabase
      .from('users')
      .select('preferences')
      .eq('id', userId)
      .single();

    const preferences = data?.preferences || {};
    return preferences.bandwidth_mode || 'auto';
  } catch (error: any) {
    logError('Failed to get bandwidth mode', error);
    return 'auto';
  }
}

/**
 * Set user bandwidth preference
 */
export async function setBandwidthMode(
  userId: string,
  mode: 'auto' | 'low' | 'high'
) {
  try {
    // Get current preferences
    const { data: user } = await supabase
      .from('users')
      .select('preferences')
      .eq('id', userId)
      .single();

    const preferences = user?.preferences || {};
    preferences.bandwidth_mode = mode;

    // Update preferences
    const { error } = await supabase
      .from('users')
      .update({ preferences })
      .eq('id', userId);

    if (error) {
      throw error;
    }

    logInfo(`Bandwidth mode set to ${mode} for user ${userId}`);
    return { success: true, mode };
  } catch (error: any) {
    logError('Failed to set bandwidth mode', error);
    throw error;
  }
}

/**
 * Check if low-bandwidth mode should be enabled
 */
export async function shouldUseLowBandwidth(userId: string): Promise<boolean> {
  const mode = await getBandwidthMode(userId);
  
  if (mode === 'low') {
    return true;
  }
  
  if (mode === 'high') {
    return false;
  }
  
  // Auto mode: detect network conditions (simplified - would use NetworkMonitor in frontend)
  // For now, default to false
  return false;
}

/**
 * Downsample media for low-bandwidth mode
 */
export function downsampleMedia(originalUrl: string, quality: 'low' | 'medium' | 'high' = 'low'): string {
  // In production, this would use image/video processing libraries
  // For now, return original URL with quality parameter
  const separator = originalUrl.includes('?') ? '&' : '?';
  return `${originalUrl}${separator}quality=${quality}`;
}

