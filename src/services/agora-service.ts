/**
 * Agora Service
 * Handles Agora token generation and room state management
 * Uses Redis for real-time state, Supabase for persistence
 */

import { RtcTokenBuilder, RtcRole } from 'agora-access-token';
import { getRedisClient } from '../config/db.js';
import { supabase } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';
import type Redis from 'ioredis';

let redis: Redis | null = null;

function getRedis(): Redis {
  if (!redis) {
    redis = getRedisClient();
  }
  return redis;
}

// Agora configuration from environment
const AGORA_APP_ID = process.env.AGORA_APP_ID || '';
const AGORA_APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE || '';

// Default room settings
const DEFAULT_ROOM_CAPACITY = 50;
const DEFAULT_TOKEN_EXPIRY = 3600; // 1 hour in seconds

export interface RoomMember {
  userId: string;
  uid: number;
  isMuted: boolean;
  isVideoEnabled: boolean;
  joinedAt: number;
}

export interface RoomState {
  roomId: string;
  members: RoomMember[];
  capacity: number;
  voiceOnly: boolean;
  createdAt: number;
}

/**
 * Generate Agora RTC token for joining a room
 */
export function generateAgoraToken(
  channelName: string,
  uid: number,
  role: RtcRole = RtcRole.PUBLISHER,
  expireTime: number = DEFAULT_TOKEN_EXPIRY
): string {
  if (!AGORA_APP_ID || !AGORA_APP_CERTIFICATE) {
    throw new Error('Agora credentials not configured');
  }

  const currentTime = Math.floor(Date.now() / 1000);
  const privilegeExpireTime = currentTime + expireTime;

  const token = RtcTokenBuilder.buildTokenWithUid(
    AGORA_APP_ID,
    AGORA_APP_CERTIFICATE,
    channelName,
    uid,
    role,
    privilegeExpireTime
  );

  return token;
}

/**
 * Get or create room state in Redis
 */
export async function getRoomState(roomId: string): Promise<RoomState | null> {
  try {
    const key = `room:${roomId}:state`;
    const stateJson = await getRedis().get(key);
    
    if (!stateJson) {
      // Try to load from Supabase and initialize Redis
      const { data: room } = await supabase
        .from('rooms')
        .select('id, name, max_capacity, voice_only')
        .eq('id', roomId)
        .single();

      if (!room) {
        return null;
      }

      const initialState: RoomState = {
        roomId,
        members: [],
        capacity: room.max_capacity || DEFAULT_ROOM_CAPACITY,
        voiceOnly: room.voice_only || false,
        createdAt: Date.now(),
      };

      await getRedis().setex(key, 86400, JSON.stringify(initialState)); // 24h expiry
      return initialState;
    }

    return JSON.parse(stateJson) as RoomState;
  } catch (error) {
    logError('Failed to get room state', error instanceof Error ? error : new Error(String(error)));
    return null;
  }
}

/**
 * Update room state in Redis
 */
export async function updateRoomState(roomId: string, state: RoomState): Promise<void> {
  try {
    const key = `room:${roomId}:state`;
    await getRedis().setex(key, 86400, JSON.stringify(state)); // 24h expiry
  } catch (error) {
    logError('Failed to update room state', error instanceof Error ? error : new Error(String(error)));
  }
}

/**
 * Add member to room
 */
export async function addRoomMember(
  roomId: string,
  userId: string,
  uid: number
): Promise<{ success: boolean; error?: string }> {
  try {
    const state = await getRoomState(roomId);
    if (!state) {
      return { success: false, error: 'Room not found' };
    }

    // Check capacity
    if (state.members.length >= state.capacity) {
      return { success: false, error: 'Room is full' };
    }

    // Check if user already in room
    const existingMember = state.members.find(m => m.userId === userId);
    if (existingMember) {
      return { success: true }; // Already in room
    }

    // Add new member
    const newMember: RoomMember = {
      userId,
      uid,
      isMuted: false,
      isVideoEnabled: !state.voiceOnly, // Video enabled unless voice-only mode
      joinedAt: Date.now(),
    };

    state.members.push(newMember);
    await updateRoomState(roomId, state);

    // Persist to Supabase (async, don't block)
    persistRoomMemberToSupabase(roomId, userId, uid).catch(err => {
      logError('Failed to persist room member', err);
    });

    return { success: true };
  } catch (error) {
    logError('Failed to add room member', error instanceof Error ? error : new Error(String(error)));
    return { success: false, error: 'Failed to join room' };
  }
}

/**
 * Remove member from room
 */
export async function removeRoomMember(roomId: string, userId: string): Promise<void> {
  try {
    const state = await getRoomState(roomId);
    if (!state) {
      return;
    }

    state.members = state.members.filter(m => m.userId !== userId);
    await updateRoomState(roomId, state);

    // Persist to Supabase (async, don't block)
    removeRoomMemberFromSupabase(roomId, userId).catch(err => {
      logError('Failed to remove room member', err);
    });
  } catch (error) {
    logError('Failed to remove room member', error instanceof Error ? error : new Error(String(error)));
  }
}

/**
 * Update member mute status
 */
export async function updateMemberMute(
  roomId: string,
  userId: string,
  isMuted: boolean
): Promise<{ success: boolean }> {
  try {
    const state = await getRoomState(roomId);
    if (!state) {
      return { success: false };
    }

    const member = state.members.find(m => m.userId === userId);
    if (member) {
      member.isMuted = isMuted;
      await updateRoomState(roomId, state);
      return { success: true };
    }

    return { success: false };
  } catch (error) {
    logError('Failed to update member mute', error instanceof Error ? error : new Error(String(error)));
    return { success: false };
  }
}

/**
 * Update member video status
 */
export async function updateMemberVideo(
  roomId: string,
  userId: string,
  isVideoEnabled: boolean
): Promise<{ success: boolean }> {
  try {
    const state = await getRoomState(roomId);
    if (!state) {
      return { success: false };
    }

    // Check if room is voice-only
    if (state.voiceOnly && isVideoEnabled) {
      return { success: false };
    }

    const member = state.members.find(m => m.userId === userId);
    if (member) {
      member.isVideoEnabled = isVideoEnabled;
      await updateRoomState(roomId, state);
      return { success: true };
    }

    return { success: false };
  } catch (error) {
    logError('Failed to update member video', error instanceof Error ? error : new Error(String(error)));
    return { success: false };
  }
}

/**
 * Get room members list
 */
export async function getRoomMembers(roomId: string): Promise<RoomMember[]> {
  try {
    const state = await getRoomState(roomId);
    return state?.members || [];
  } catch (error) {
    logError('Failed to get room members', error instanceof Error ? error : new Error(String(error)));
    return [];
  }
}

/**
 * Persist room member to Supabase (async)
 */
async function persistRoomMemberToSupabase(roomId: string, userId: string, uid: number): Promise<void> {
  try {
    await supabase.from('room_members').upsert({
      room_id: roomId,
      user_id: userId,
      agora_uid: uid,
      joined_at: new Date().toISOString(),
    });
  } catch (error) {
    // Silent fail - Redis is source of truth
    logError('Failed to persist room member to Supabase', error instanceof Error ? error : new Error(String(error)));
  }
}

/**
 * Remove room member from Supabase (async)
 */
async function removeRoomMemberFromSupabase(roomId: string, userId: string): Promise<void> {
  try {
    await supabase
      .from('room_members')
      .delete()
      .eq('room_id', roomId)
      .eq('user_id', userId);
  } catch (error) {
    // Silent fail - Redis is source of truth
    logError('Failed to remove room member from Supabase', error instanceof Error ? error : new Error(String(error)));
  }
}

