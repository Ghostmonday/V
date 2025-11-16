/**
 * Nickname Service
 * Handles custom nicknames per room
 */

import { supabase } from '../config/db.js';
import { getRedisClient } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';

const redis = getRedisClient();

/**
 * Set nickname for user in a room
 */
export async function setNickname(
  userId: string,
  roomId: string,
  nickname: string
) {
  try {
    // Validate nickname length
    if (nickname.length > 32) {
      throw new Error('Nickname must be 32 characters or less');
    }

    // Update or insert nickname
    const { error } = await supabase
      .from('room_memberships')
      .update({ nickname })
      .eq('user_id', userId)
      .eq('room_id', roomId);

    if (error) {
      // Try insert if update failed (user not in room yet)
      const { error: insertError } = await supabase
        .from('room_memberships')
        .insert({
          user_id: userId,
          room_id: roomId,
          nickname,
          role: 'member'
        });

      if (insertError) {
        throw insertError;
      }
    }

    // Broadcast nickname change
    await redis.publish(
      `room:${roomId}`,
      JSON.stringify({
        type: 'nickname_changed',
        user_id: userId,
        nickname,
        timestamp: Date.now()
      })
    );

    logInfo(`Nickname set for user ${userId} in room ${roomId}: ${nickname}`);
    return { success: true, nickname };
  } catch (error: any) {
    logError('Failed to set nickname', error);
    throw error;
  }
}

/**
 * Get nickname for user in a room
 */
export async function getNickname(userId: string, roomId: string): Promise<string | null> {
  try {
    const { data } = await supabase
      .from('room_memberships')
      .select('nickname')
      .eq('user_id', userId)
      .eq('room_id', roomId)
      .single();

    return data?.nickname || null;
  } catch (error: any) {
    logError('Failed to get nickname', error);
    return null;
  }
}

/**
 * Get all nicknames for a room
 */
export async function getRoomNicknames(roomId: string): Promise<Record<string, string>> {
  try {
    const { data } = await supabase
      .from('room_memberships')
      .select('user_id, nickname')
      .eq('room_id', roomId)
      .not('nickname', 'is', null);

    const nicknames: Record<string, string> = {};
    if (data) {
      for (const member of data) {
        if (member.nickname) {
          nicknames[member.user_id] = member.nickname;
        }
      }
    }

    return nicknames;
  } catch (error: any) {
    logError('Failed to get room nicknames', error);
    return {};
  }
}

