/**
 * Pinned Items Service
 * Handles pinned rooms/channels for quick access
 */

import { supabase } from '../config/database-config.js';
import { logError, logInfo } from '../shared/logger-shared.js';

/**
 * Pin a room
 */
export async function pinRoom(userId: string, roomId: string) {
  try {
    const { error } = await supabase.from('pinned_items').upsert(
      {
        user_id: userId,
        room_id: roomId,
        pinned_at: new Date().toISOString(),
      },
      {
        onConflict: 'user_id,room_id',
      }
    );

    if (error) {
      throw error;
    }

    logInfo(`Room ${roomId} pinned by user ${userId}`);
    return { success: true };
  } catch (error: any) {
    logError('Failed to pin room', error);
    throw error;
  }
}

/**
 * Unpin a room
 */
export async function unpinRoom(userId: string, roomId: string) {
  try {
    const { error } = await supabase
      .from('pinned_items')
      .delete()
      .eq('user_id', userId)
      .eq('room_id', roomId);

    if (error) {
      throw error;
    }

    logInfo(`Room ${roomId} unpinned by user ${userId}`);
    return { success: true };
  } catch (error: any) {
    logError('Failed to unpin room', error);
    throw error;
  }
}

/**
 * Get pinned rooms for user
 */
export async function getPinnedRooms(userId: string) {
  try {
    const { data, error } = await supabase
      .from('pinned_items')
      .select(
        `
        room_id,
        pinned_at,
        rooms (
          id,
          slug,
          title,
          created_at
        )
      `
      )
      .eq('user_id', userId)
      .order('pinned_at', { ascending: false });

    if (error) {
      throw error;
    }

    return data || [];
  } catch (error: any) {
    logError('Failed to get pinned rooms', error);
    return [];
  }
}

/**
 * Check if room is pinned
 */
export async function isRoomPinned(userId: string, roomId: string): Promise<boolean> {
  try {
    const { data } = await supabase
      .from('pinned_items')
      .select('id')
      .eq('user_id', userId)
      .eq('room_id', roomId)
      .single();

    return !!data;
  } catch {
    return false;
  }
}

/**
 * Pin a message
 */
export async function pinMessage(messageId: string) {
  try {
    const { error } = await supabase
      .from('messages')
      .update({ is_pinned: true })
      .eq('id', messageId);

    if (error) {
      throw error;
    }

    logInfo(`Message ${messageId} pinned`);
    return { success: true };
  } catch (error: any) {
    logError('Failed to pin message', error);
    throw error;
  }
}

/**
 * Unpin a message
 */
export async function unpinMessage(messageId: string) {
  try {
    const { error } = await supabase
      .from('messages')
      .update({ is_pinned: false })
      .eq('id', messageId);

    if (error) {
      throw error;
    }

    logInfo(`Message ${messageId} unpinned`);
    return { success: true };
  } catch (error: any) {
    logError('Failed to unpin message', error);
    throw error;
  }
}
