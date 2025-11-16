/**
 * Room Service - Real Implementation
 * Real Supabase integration, no stubs
 */

import { supabase } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';

/**
 * Create a room
 * @param name - Room name
 * @param userId - Creator user ID
 * @returns Created room object
 */
export async function createRoom(name: string, userId: string): Promise<any> {
  try {
    if (!name || name.trim().length === 0) {
      throw new Error('Room name is required');
    }

    if (!userId) {
      throw new Error('User ID is required');
    }

    // Check if name is taken
    const { data: existing } = await supabase
      .from('rooms')
      .select('id')
      .eq('name', name.trim())
      .single();

    if (existing) {
      throw new Error('Name taken');
    }

    // Create room
    const { data: room, error } = await supabase
      .from('rooms')
      .insert({
        name: name.trim(),
        creator_id: userId,
        is_private: false,
      })
      .select()
      .single();

    if (error) {
      logError('Failed to create room', error);
      throw new Error(error.message || 'Failed to create room');
    }

    logInfo(`Room created: ${room.id} - ${room.name}`);
    return room;
  } catch (error: any) {
    logError('createRoom error', error);
    throw error;
  }
}

/**
 * Join a room
 * @param roomId - Room ID
 * @param userId - User ID
 * @returns Join result with LiveKit token
 */
export async function joinRoom(roomId: string, userId: string): Promise<{ success: boolean; room?: any; livekitToken?: string }> {
  try {
    // Check if room exists and is private
    const { data: room, error: roomError } = await supabase
      .from('rooms')
      .select('*')
      .eq('id', roomId)
      .single();

    if (roomError || !room) {
      throw new Error('Room not found');
    }

    if (room.is_private) {
      // Check if user is already a member
      const { data: member } = await supabase
        .from('room_members')
        .select('id')
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .single();

      if (!member) {
        throw new Error('Room is private and you are not a member');
      }
    }

    // Insert membership (ON CONFLICT handles duplicate joins)
    const { error: joinError } = await supabase
      .from('room_members')
      .insert({
        room_id: roomId,
        user_id: userId,
      })
      .select()
      .single();

    if (joinError && joinError.code !== '23505') { // 23505 = unique violation (already joined)
      logError('Failed to join room', joinError);
      throw new Error(joinError.message || 'Failed to join room');
    }

    // Generate LiveKit token for calls
    const { generateLiveKitToken } = await import('./livekit-token-service.js');
    const livekitToken = await generateLiveKitToken(userId, roomId, 'guest');

    logInfo(`User ${userId} joined room ${roomId}`);
    return { success: true, room, livekitToken: livekitToken || undefined };
  } catch (error: any) {
    logError('joinRoom error', error);
    throw error;
  }
}

/**
 * Get room by ID
 */
export async function getRoom(roomId: string): Promise<any | null> {
  try {
    const { data, error } = await supabase
      .from('rooms')
      .select('*')
      .eq('id', roomId)
      .single();

    if (error || !data) {
      return null;
    }

    return data;
  } catch (error) {
    logError('getRoom error', error instanceof Error ? error : new Error(String(error)));
    return null;
  }
}

/**
 * List rooms
 */
export async function listRooms(isPrivate?: boolean): Promise<any[]> {
  try {
    let query = supabase.from('rooms').select('*');

    if (isPrivate !== undefined) {
      query = query.eq('is_private', isPrivate);
    }

    const { data, error } = await query.order('created_at', { ascending: false });

    if (error) {
      throw error;
    }

    return data || [];
  } catch (error) {
    logError('listRooms error', error instanceof Error ? error : new Error(String(error)));
    return [];
  }
}
