/**
 * Room Routes - Real Implementation
 * POST /chat-rooms - Create room
 * POST /chat-rooms/:id/join - Join room
 */

import { Router, Response, NextFunction } from 'express';
import { createRoom, joinRoom, getRoom } from '../services/room-service.js';
import { authMiddleware } from '../middleware/auth.js';
import { ageVerificationMiddleware } from '../middleware/age-verification.js';
import { logError } from '../shared/logger.js';
import { AuthenticatedRequest } from '../types/auth.types.js';

const router = Router();

/**
 * POST /chat-rooms
 * Create a new room
 * Body: { name: string }
 * Requires: Authentication
 */
router.post('/chat-rooms', authMiddleware, ageVerificationMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { name } = req.body;

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return res.status(400).json({ error: 'Room name is required' });
    }

    const room = await createRoom(name, userId);

    res.status(201).json({
      success: true,
      room: {
        id: room.id,
        name: room.name,
        creator_id: room.creator_id,
        is_private: room.is_private,
        created_at: room.created_at,
      },
    });
  } catch (error) {
    if (error instanceof Error && error.message === 'Name taken') {
      return res.status(400).json({ error: 'Name taken' });
    }
    logError('Create room error', error instanceof Error ? error : new Error(String(error)));
    next(error);
  }
});

/**
 * POST /chat-rooms/:id/join
 * Join a room - Returns Agora token for video/audio streams
 * Requires: Authentication
 * Response: { token: string, channelName: string, uid: number, members: RoomMember[] }
 */
router.post('/chat-rooms/:id/join', authMiddleware, ageVerificationMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const roomId = req.params.id;

    // Import Agora service
    const {
      generateAgoraToken,
      addRoomMember,
      getRoomMembers,
      getRoomState,
    } = await import('../services/agora-service.js');

    // Get room state
    const roomState = await getRoomState(roomId);
    if (!roomState) {
      return res.status(404).json({ error: 'Room not found' });
    }

    // Generate unique UID for Agora (use hash of userId for consistency)
    const uid = Math.abs(parseInt(userId.replace(/-/g, '').substring(0, 8), 16)) % 2147483647;

    // Add user to room
    const joinResult = await addRoomMember(roomId, userId, uid);
    if (!joinResult.success) {
      return res.status(400).json({ error: joinResult.error || 'Failed to join room' });
    }

    // Generate Agora token
    const token = generateAgoraToken(roomId, uid);
    
    // Get current members
    const members = await getRoomMembers(roomId);

    res.json({
      success: true,
      token,
      channelName: roomId,
      uid,
      members: members.map(m => ({
        userId: m.userId,
        uid: m.uid,
        isMuted: m.isMuted,
        isVideoEnabled: m.isVideoEnabled,
      })),
      roomState: {
        capacity: roomState.capacity,
        voiceOnly: roomState.voiceOnly,
        memberCount: members.length,
      },
    });
  } catch (error) {
    if (error instanceof Error) {
      if (error.message === 'Room not found') {
        return res.status(404).json({ error: error.message });
      }
      if (error.message.includes('private')) {
        return res.status(403).json({ error: error.message });
      }
      if (error.message.includes('Agora credentials')) {
        return res.status(500).json({ error: 'Video service not configured' });
      }
    }
    logError('Join room error', error instanceof Error ? error : new Error(String(error)));
    next(error);
  }
});

/**
 * GET /chat-rooms/:id
 * Get room details
 */
router.get('/chat-rooms/:id', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const roomId = req.params.id;
    const room = await getRoom(roomId);

    if (!room) {
      return res.status(404).json({ error: 'Room not found' });
    }

    res.json({ room });
  } catch (error) {
    logError('Get room error', error instanceof Error ? error : new Error(String(error)));
    next(error);
  }
});

export default router;
