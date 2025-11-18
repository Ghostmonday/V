/**
 * VIBES Analytics Service
 * Track metrics for $5K/month goal
 */

import { supabase } from '../../config/db.ts';
import { logError } from '../../shared/logger.js';

export interface VIBESAnalytics {
  top_creators: Array<{ user_id: string; conversation_count: number }>;
}

/**
 * Get VIBES analytics
 */
export async function getVIBESAnalytics(): Promise<VIBESAnalytics> {
  try {
    // Top creators (by conversation creation)
    const { data: creators } = await supabase
      .from('conversations')
      .select('created_by')
      .not('created_by', 'is', null);

    const creatorCounts: Record<string, number> = {};
    (creators || []).forEach((conv: any) => {
      if (conv.created_by) {
        creatorCounts[conv.created_by] = (creatorCounts[conv.created_by] || 0) + 1;
      }
    });

    const topCreators = Object.entries(creatorCounts)
      .map(([user_id, conversation_count]) => ({ user_id, conversation_count }))
      .sort((a, b) => b.conversation_count - a.conversation_count)
      .slice(0, 10);

    return {
      top_creators: topCreators,
    };
  } catch (error) {
    logError('Failed to get VIBES analytics', error);
    throw error;
  }
}
