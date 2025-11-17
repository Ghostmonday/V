/**
 * Message Flagging Service
 * Stores flagged messages with reason for admin review
 */

import { supabase } from '../config/db.ts';
import { logError, logInfo } from '../shared/logger.js';

export interface FlaggedMessage {
  id: string;
  message_id: string;
  room_id: string;
  user_id: string;
  reason: string; // 'toxicity', 'spam', 'harassment', 'inappropriate', 'other'
  score: number; // 0-1 toxicity score
  flagged_by: string; // User ID who flagged (or 'system' for auto-flag)
  status: 'pending' | 'reviewed' | 'dismissed' | 'action_taken';
  reviewed_by?: string;
  reviewed_at?: string;
  action_taken?: string; // 'warned', 'muted', 'banned', 'message_deleted'
  metadata: Record<string, any>;
  created_at: string;
}

/**
 * Flag a message for review
 */
export async function flagMessage(
  messageId: string,
  roomId: string,
  userId: string,
  reason: string,
  score: number,
  flaggedBy: string | null = null, // null = system flag, UUID = user flag
  metadata: Record<string, any> = {}
): Promise<FlaggedMessage | null> {
  try {
    // Convert 'system' string to null for database
    const flaggedByValue = flaggedBy === 'system' ? null : flaggedBy;
    
    const { data, error } = await supabase
      .from('flagged_messages')
      .insert({
        message_id: messageId,
        room_id: roomId,
        user_id: userId,
        reason,
        score,
        flagged_by: flaggedByValue, // null for system flags, UUID for user flags
        status: 'pending',
        metadata,
      })
      .select()
      .single();

    if (error) {
      throw error;
    }

    logInfo(`Message flagged: ${messageId} by ${flaggedByValue || 'system'} for ${reason}`);
    return data as FlaggedMessage;
  } catch (error: any) {
    logError('Failed to flag message', error);
    return null;
  }
}

/**
 * Get flagged messages for admin review
 */
export async function getFlaggedMessages(
  status: 'pending' | 'reviewed' | 'dismissed' | 'action_taken' | 'all' = 'pending',
  limit: number = 50,
  offset: number = 0
): Promise<FlaggedMessage[]> {
  try {
    let query = supabase
      .from('flagged_messages')
      .select('*')
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (status !== 'all') {
      query = query.eq('status', status);
    }

    const { data, error } = await query;

    if (error) {
      throw error;
    }

    return (data || []) as FlaggedMessage[];
  } catch (error: any) {
    logError('Failed to get flagged messages', error);
    return [];
  }
}

/**
 * Review a flagged message (admin action)
 */
export async function reviewFlaggedMessage(
  flagId: string,
  reviewerId: string,
  action: 'dismiss' | 'warn' | 'mute' | 'ban' | 'delete_message',
  notes?: string
): Promise<boolean> {
  try {
    const actionMap: Record<string, string> = {
      dismiss: 'dismissed',
      warn: 'action_taken',
      mute: 'action_taken',
      ban: 'action_taken',
      delete_message: 'action_taken',
    };

    const { error } = await supabase
      .from('flagged_messages')
      .update({
        status: actionMap[action] as any,
        reviewed_by: reviewerId,
        reviewed_at: new Date().toISOString(),
        action_taken: action,
        metadata: { notes },
      })
      .eq('id', flagId);

    if (error) {
      throw error;
    }

    logInfo(`Flag reviewed: ${flagId} by ${reviewerId} - action: ${action}`);
    return true;
  } catch (error: any) {
    logError('Failed to review flagged message', error);
    return false;
  }
}

