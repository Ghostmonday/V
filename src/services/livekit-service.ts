/**
 * LiveKit Service
 * Complete voice/video session lifecycle management
 */

import { RoomServiceClient, AccessToken } from 'livekit-server-sdk';
import { recordTelemetryEvent } from './telemetry-service.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { getLiveKitKeys } from './api-keys-service.js';
import { getRedisClient } from '../config/database-config.js';
import type { VoiceSession, VoiceStats } from '../types/message-types.js';

const redis = getRedisClient();

export class LiveKitService {
  private roomService: RoomServiceClient;
  private performanceStats: Map<string, VoiceStats> = new Map();
  private initialized: boolean = false;

  async initialize() {
    if (this.initialized) return;

    try {
      const livekitKeys = await getLiveKitKeys();
      const livekitHost = livekitKeys.host || livekitKeys.url;
      const livekitApiKey = livekitKeys.apiKey;
      const livekitApiSecret = livekitKeys.apiSecret;

      if (!livekitHost || !livekitApiKey || !livekitApiSecret) {
        logError(
          'LiveKit configuration missing',
          new Error('LIVEKIT_HOST, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET required in vault')
        );
        throw new Error('LiveKit not configured');
      }

      this.roomService = new RoomServiceClient(livekitHost, livekitApiKey, livekitApiSecret);
      this.initialized = true;
    } catch (error) {
      logError(
        'Failed to initialize LiveKit service',
        error instanceof Error ? error : new Error(String(error))
      );
      throw error;
    }
  }

  constructor() {
    // Initialize will be called async - use ensureInitialized() before operations
  }

  private async ensureInitialized() {
    if (!this.initialized) {
      await this.initialize();
    }
  }

  /**
   * SIN-101: Create voice room
   */
  async createVoiceRoom(roomName: string, maxParticipants: number = 50): Promise<string> {
    await this.ensureInitialized();
    try {
      if (!roomName || typeof roomName !== 'string') {
        throw new Error('Invalid roomName');
      }

      if (typeof maxParticipants !== 'number' || maxParticipants < 1) {
        maxParticipants = 50;
      }

      const room = await this.roomService.createRoom({
        // Race: concurrent creates can conflict, room may already exist
        name: roomName,
        emptyTimeout: 300, // 5 minutes
        maxParticipants,
      });

      try {
        await recordTelemetryEvent('voice_room_created', {
          room_id: roomName,
        });
      } catch (telemetryError) {
        logError('Failed to log telemetry for room creation', telemetryError);
      }

      // Track room as active for participant sync
      const roomNameToTrack = room.name || roomName;
      // Room will be tracked when getVoiceSession is called (which syncs participants)

      return room.name || roomName;
    } catch (error: any) {
      logError('Failed to create voice room', error);
      throw new Error('Could not create voice room');
    }
  }

  /**
   * SIN-101: Generate participant token
   * Caches tokens in Redis for 5 minutes to reduce auth overhead and fix iOS reconnect stutter
   */
  async generateParticipantToken(
    roomName: string,
    participantIdentity: string,
    userName: string = ''
  ): Promise<string> {
    await this.ensureInitialized();

    if (!roomName || typeof roomName !== 'string') {
      throw new Error('Invalid roomName');
    }

    if (!participantIdentity || typeof participantIdentity !== 'string') {
      throw new Error('Invalid participantIdentity');
    }

    // Check Redis cache for valid token (<5min old)
    const cacheKey = `user:livekit:token:${participantIdentity}:${roomName}`;
    try {
      const cached = await redis.get(cacheKey);
      if (cached) {
        // Token exists and is valid (Redis TTL ensures <5min)
        return cached;
      }
    } catch (cacheError) {
      // Cache miss or error - proceed to generate new token
      logInfo('LiveKit token cache miss or error, generating new token', cacheError);
    }

    const livekitKeys = await getLiveKitKeys();
    const livekitApiKey = livekitKeys.apiKey;
    const livekitApiSecret = livekitKeys.apiSecret;

    if (!livekitApiKey || !livekitApiSecret) {
      throw new Error('LiveKit API credentials not configured');
    }

    const token = new AccessToken(livekitApiKey, livekitApiSecret, {
      identity: participantIdentity,
      name: userName,
    });

    token.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    const jwtToken = token.toJwt();

    // Cache token for 5 minutes (300 seconds)
    try {
      await redis.setex(cacheKey, 300, jwtToken);
    } catch (cacheError) {
      // Cache write failed - log but don't fail token generation
      logInfo('Failed to cache LiveKit token', cacheError);
    }

    return jwtToken;
  }

  /**
   * SIN-101: Get room session info with participant sync
   */
  async getVoiceSession(roomName: string): Promise<VoiceSession | null> {
    await this.ensureInitialized();
    try {
      if (!roomName || typeof roomName !== 'string') {
        throw new Error('Invalid roomName');
      }

      const rooms = await this.roomService.listRooms([roomName]);
      const room = rooms.find((r) => r.name === roomName);

      if (!room) {
        return null;
      }

      // Sync participants from LiveKit to Redis for fast lookups
      const participants = await this.roomService.listParticipants(roomName);

      // Track room as active for periodic sync
      trackActiveRoom(roomName);

      // Update Redis cache with current participants for presence sync
      const participantIds = participants.map((p) => p.identity);
      const cacheKey = `livekit:room:${roomName}:participants`;
      try {
        // Store participant list in Redis with 5-minute TTL
        await redis.setex(cacheKey, 300, JSON.stringify(participantIds));

        // Also update individual participant presence
        for (const participant of participants) {
          await redis.set(`presence:${participant.identity}`, 'online', 'EX', 300);
        }
      } catch (cacheError) {
        logInfo('Failed to cache LiveKit participants', cacheError);
        // Continue even if cache fails
      }

      return {
        room_name: roomName,
        participant_count: participants.length,
        participants: participants.map((p) => ({
          id: p.sid,
          user_id: p.identity,
          identity: p.identity,
          is_speaking: false, // Would need active subscription to track
          audio_level: 0, // Would need active subscription
          connection_quality: (p as any).connectionQuality || 0,
        })),
      };
    } catch (error: any) {
      logError('Failed to get voice session', error);
      return null;
    }
  }

  /**
   * Sync participants for a room (called periodically)
   */
  async syncRoomParticipants(roomName: string): Promise<void> {
    await this.ensureInitialized();
    try {
      const session = await this.getVoiceSession(roomName);
      if (session) {
        logInfo('Synced LiveKit participants', { roomName, count: session.participant_count });
      }
    } catch (error) {
      logError(
        'Failed to sync room participants',
        error instanceof Error ? error : new Error(String(error))
      );
    }
  }

  /**
   * SIN-101: Disconnect participant
   */
  async disconnectParticipant(roomName: string, participantIdentity: string): Promise<void> {
    await this.ensureInitialized();
    try {
      if (!roomName || typeof roomName !== 'string') {
        throw new Error('Invalid roomName');
      }

      if (!participantIdentity || typeof participantIdentity !== 'string') {
        throw new Error('Invalid participantIdentity');
      }

      await this.roomService.removeParticipant(roomName, participantIdentity); // Silent fail: participant already disconnected, no error thrown

      try {
        await recordTelemetryEvent('voice_participant_disconnected', {
          room_id: roomName,
        });
      } catch (telemetryError) {
        logError('Failed to log telemetry for disconnection', telemetryError); // Silent fail: disconnection succeeded but not logged
      }
    } catch (error: any) {
      logError('Failed to disconnect participant', error); // Silent fail: error swallowed, no retry
    }
  }

  /**
   * SIN-104: Log voice performance stats
   */
  async logVoiceStats(roomName: string, stats: VoiceStats): Promise<void> {
    await this.ensureInitialized();
    if (!roomName || typeof roomName !== 'string') {
      logError('Invalid roomName for stats', new Error('Invalid roomName'));
      return;
    }

    if (!stats || typeof stats !== 'object') {
      logError('Invalid stats object', new Error('Invalid stats'));
      return;
    }

    this.performanceStats.set(roomName, stats); // Race: concurrent stats updates can overwrite each other

    try {
      await recordTelemetryEvent('voice_stats', {
        // Silent fail: stats lost if telemetry fails
        room_id: roomName,
        latency_ms: stats.latency,
        features: {
          packet_loss: stats.packet_loss,
          jitter: stats.jitter,
          bitrate: stats.bitrate,
        },
      });
    } catch (telemetryError) {
      logError('Failed to log voice stats telemetry', telemetryError); // Silent fail: stats not persisted
    }

    // Alert on poor performance
    if (stats.packet_loss > 0.1 || stats.latency > 300) {
      try {
        await recordTelemetryEvent('voice_quality_degraded', {
          room_id: roomName,
          features: {
            packet_loss: stats.packet_loss,
            latency: stats.latency,
            jitter: stats.jitter,
          },
        });
      } catch (telemetryError) {
        logError('Failed to log degraded quality', telemetryError);
      }
    }
  }

  /**
   * SIN-104: Get performance stats
   */
  getPerformanceStats(roomName: string): VoiceStats | undefined {
    if (!roomName || typeof roomName !== 'string') {
      return undefined;
    }
    return this.performanceStats.get(roomName);
  }

  /**
   * Cleanup empty rooms
   */
  async cleanupEmptyRooms(): Promise<void> {
    await this.ensureInitialized();
    try {
      const rooms = await this.roomService.listRooms(); // No timeout - can hang if LiveKit API slow
      const now = Date.now();

      for (const room of rooms) {
        // Delete rooms empty for more than 1 hour
        if (room.numParticipants === 0) {
          const creationTime =
            typeof room.creationTime === 'string'
              ? new Date(room.creationTime).getTime()
              : (room.creationTime as any).getTime?.() || now;
          if (now - creationTime > 3600000) {
            await this.roomService.deleteRoom(room.name);
            // Untrack room when deleted
            untrackActiveRoom(room.name);
            try {
              await recordTelemetryEvent('voice_room_cleaned', {
                room_id: room.name,
              });
            } catch (telemetryError) {
              logError('Failed to log room cleanup', telemetryError);
            }
          }
        }
      }
    } catch (error: any) {
      logError('Failed to cleanup rooms', error); // Silent fail: cleanup errors swallowed, rooms not cleaned
    }
  }
}

export const liveKitService = new LiveKitService();

// Periodic cleanup (every hour)
setInterval(() => {
  liveKitService.cleanupEmptyRooms().catch((err) => {
    logError('Error in periodic room cleanup', err);
  });
}, 3600000);

// Periodic participant sync (every 30 seconds for active rooms)
// This ensures presence state stays in sync between LiveKit and Redis
const activeRooms = new Set<string>();
setInterval(() => {
  // Sync participants for all active rooms
  activeRooms.forEach((roomName) => {
    liveKitService.syncRoomParticipants(roomName).catch((err) => {
      logError('Failed to sync room participants', err);
    });
  });
}, 30000); // 30 seconds

// Track active rooms (call this when room is created/joined)
export function trackActiveRoom(roomName: string): void {
  activeRooms.add(roomName);
}

// Untrack room when empty (call this when room is deleted/emptied)
export function untrackActiveRoom(roomName: string): void {
  activeRooms.delete(roomName);
}
