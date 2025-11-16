/**
 * Usage Tracking Service
 * Tracks user usage for subscription limits
 */

import { create, findMany } from '../shared/supabase-helpers.js';
import { logError } from '../shared/logger.js';
import { getSubscriptionLimits } from './subscription-service.js';

export async function trackUsage(
  userId: string,
  eventType: string,
  amount: number = 1,
  metadata?: Record<string, unknown>
): Promise<void> {
  try {
    await create('usage_stats', {
      user_id: userId,
      event_type: eventType,
      metadata: { amount, ...metadata },
      ts: new Date().toISOString()
    });
  } catch (error) {
    logError('Failed to track usage', error instanceof Error ? error : new Error(String(error)));
    // Don't throw - usage tracking shouldn't break the app
  }
}

export async function getUsageCount(
  userId: string,
  eventType: string,
  period: 'month' | 'day' = 'month'
): Promise<number> {
  try {
    const now = new Date();
    const startDate = period === 'month'
      ? new Date(now.getFullYear(), now.getMonth(), 1)
      : new Date(now.setHours(0, 0, 0, 0));

    const stats = await findMany<{ metadata: { amount?: number } }>('usage_stats', {
      filter: {
        user_id: userId,
        event_type: eventType,
        ts: { gte: startDate.toISOString() }
      }
    });

    return stats.reduce((sum, stat) => {
      return sum + (stat.metadata?.amount || 1);
    }, 0);
  } catch (error) {
    logError('Failed to get usage count', error instanceof Error ? error : new Error(String(error)));
    return 0;
  }
}

export async function checkUsageLimit(
  userId: string,
  limitType: 'aiMessages' | 'maxRooms' | 'storageMB' | 'voiceCallMinutes',
  currentUsage?: number
): Promise<{ allowed: boolean; limit: number; used: number }> {
  try {
    const limits = await getSubscriptionLimits(userId);
    const limit = limits[limitType];

    if (limit === -1) {
      return { allowed: true, limit: -1, used: 0 };
    }

    let used = currentUsage;
    if (used === undefined) {
      const eventTypeMap: Record<string, string> = {
        aiMessages: 'ai_message',
        maxRooms: 'room_created',
        storageMB: 'file_upload',
        voiceCallMinutes: 'voice_call'
      };
      used = await getUsageCount(userId, eventTypeMap[limitType] || limitType, 'month');
    }

    return {
      allowed: used < limit,
      limit,
      used
    };
  } catch (error) {
    logError('Failed to check usage limit', error instanceof Error ? error : new Error(String(error)));
    return { allowed: false, limit: 0, used: 0 };
  }
}

