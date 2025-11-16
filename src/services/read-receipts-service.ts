/**
 * Read Receipts Service
 * Handles message read receipts (delivered_at, read_at, seen_at)
 */

import { supabase } from '../config/db.js';
import { getRedisClient } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';

const redis = getRedisClient();

/**
 * Mark message as delivered
 */
export async function markDelivered(messageId: string, userId: string): Promise<void> {
  try {
    await supabase.from('message_receipts').upsert({
      message_id: messageId,
      user_id: userId,
      delivered_at: new Date().toISOString()
    }, {
      onConflict: 'message_id,user_id'
    });

    // Broadcast delivery receipt via Redis
    await redis.publish(
      `receipts:${messageId}`,
      JSON.stringify({
        type: 'delivered',
        message_id: messageId,
        user_id: userId,
        timestamp: Date.now()
      })
    );
  } catch (error: any) {
    logError('Failed to mark message as delivered', error);
    throw error;
  }
}

/**
 * Mark message as read/seen
 */
export async function markRead(messageId: string, userId: string): Promise<void> {
  try {
    await supabase.from('message_receipts').upsert({
      message_id: messageId,
      user_id: userId,
      read_at: new Date().toISOString(),
      seen_at: new Date().toISOString() // Also set seen_at for consistency
    }, {
      onConflict: 'message_id,user_id'
    });

    // Broadcast read receipt via Redis
    await redis.publish(
      `receipts:${messageId}`,
      JSON.stringify({
        type: 'read',
        message_id: messageId,
        user_id: userId,
        timestamp: Date.now()
      })
    );

    logInfo(`Message ${messageId} marked as read by user ${userId}`);
  } catch (error: any) {
    logError('Failed to mark message as read', error);
    throw error;
  }
}

/**
 * Mark multiple messages as read (batch operation)
 */
export async function markMultipleRead(messageIds: string[], userId: string): Promise<void> {
  try {
    const receipts = messageIds.map(messageId => ({
      message_id: messageId,
      user_id: userId,
      read_at: new Date().toISOString(),
      seen_at: new Date().toISOString()
    }));

    // Batch upsert
    await supabase.from('message_receipts').upsert(receipts, {
      onConflict: 'message_id,user_id'
    });

    // Broadcast each receipt
    for (const messageId of messageIds) {
      await redis.publish(
        `receipts:${messageId}`,
        JSON.stringify({
          type: 'read',
          message_id: messageId,
          user_id: userId,
          timestamp: Date.now()
        })
      );
    }

    logInfo(`Marked ${messageIds.length} messages as read by user ${userId}`);
  } catch (error: any) {
    logError('Failed to mark multiple messages as read', error);
    throw error;
  }
}

/**
 * Get read receipts for a message
 */
export async function getReadReceipts(messageId: string): Promise<Array<{
  user_id: string;
  delivered_at: string | null;
  read_at: string | null;
  seen_at: string | null;
}>> {
  try {
    const { data, error } = await supabase
      .from('message_receipts')
      .select('user_id, delivered_at, read_at, seen_at')
      .eq('message_id', messageId);

    if (error) {
      throw error;
    }

    return data || [];
  } catch (error: any) {
    logError('Failed to get read receipts', error);
    return [];
  }
}

/**
 * Get read status for messages in a room
 */
export async function getRoomReadStatus(
  roomId: string,
  userId: string
): Promise<Record<string, { read_at: string | null; seen_at: string | null }>> {
  try {
    // Get all messages in room
    const { data: messages } = await supabase
      .from('messages')
      .select('id')
      .eq('room_id', roomId);

    if (!messages || messages.length === 0) {
      return {};
    }

    const messageIds = messages.map(m => m.id);

    // Get receipts for these messages
    const { data: receipts } = await supabase
      .from('message_receipts')
      .select('message_id, read_at, seen_at')
      .in('message_id', messageIds)
      .eq('user_id', userId);

    const status: Record<string, { read_at: string | null; seen_at: string | null }> = {};
    
    if (receipts) {
      for (const receipt of receipts) {
        status[receipt.message_id] = {
          read_at: receipt.read_at,
          seen_at: receipt.seen_at
        };
      }
    }

    return status;
  } catch (error: any) {
    logError('Failed to get room read status', error);
    return {};
  }
}

