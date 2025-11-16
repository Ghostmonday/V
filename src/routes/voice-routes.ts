/**
 * Voice/Video Routes
 * SIN-101: LiveKit integration for voice channels
 */

import { Router, Response, NextFunction } from 'express';
import { liveKitService } from '../services/livekit-service.js';
import { authMiddleware } from '../middleware/auth.js';
import { logError } from '../shared/logger.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { getLiveKitKeys } from '../services/api-keys-service.js';
import { checkQuota, incrementUsage } from '../services/usageMeter.js';

const router = Router();

// Apply auth middleware
router.use(authMiddleware);

/**
 * POST /voice/rooms/:room_name/join
 * Create or join voice room
 */
router.post('/rooms/:room_name/join', async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const { room_name } = req.params;
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!room_name || typeof room_name !== 'string') {
      return res.status(400).json({ error: 'Invalid room_name' });
    }

    // Check voice minutes quota (free tier: 30 minutes/month)
    const VOICE_MINUTES_LIMIT = 30;
    const withinQuota = await checkQuota(userId, 'voice_minutes', VOICE_MINUTES_LIMIT);
    if (!withinQuota) {
      return res.status(403).json({
        error: 'Voice minutes limit reached',
        upgrade_url: '/subscription/upgrade',
        limit: VOICE_MINUTES_LIMIT,
        message: `You've reached your monthly voice minutes limit. Upgrade to Pro for unlimited voice calls.`
      });
    }

    // Create or get voice room
    const voiceRoomName = `voice_${room_name}`;
    await liveKitService.createVoiceRoom(voiceRoomName);
    
    // Note: Voice minutes will be incremented when call ends (tracked client-side or via webhook)
    // For now, increment by 1 minute on join (will be updated with actual duration later)
    await incrementUsage(userId, 'voice_minutes', 1);

    // Generate participant token
    const token = await liveKitService.generateParticipantToken( // Silent fail: token generation can throw, no retry
      voiceRoomName,
      userId,
      req.user?.username || req.user?.handle || ''
    );

    // Get LiveKit URL from vault
    const livekitKeys = await getLiveKitKeys();
    const wsUrl = livekitKeys.url || livekitKeys.host || '';

    res.json({
      token,
      room_name: voiceRoomName,
      ws_url: wsUrl,
    });
  } catch (error: any) {
    logError('Voice join error', error);
    res.status(500).json({ error: 'Failed to join voice channel' });
  }
});

/**
 * GET /voice/rooms/:room_name
 * Get voice room info
 */
router.get('/rooms/:room_name', async (req, res, next) => {
  try {
    const { room_name } = req.params;

    if (!room_name || typeof room_name !== 'string') {
      return res.status(400).json({ error: 'Invalid room_name' });
    }

    const session = await liveKitService.getVoiceSession(room_name);

    if (!session) {
      return res.status(404).json({ error: 'Voice room not found' });
    }

    res.json(session);
  } catch (error: any) {
    logError('Get voice room error', error);
    res.status(500).json({ error: 'Failed to get voice room info' });
  }
});

/**
 * GET /voice/rooms/:room_name/stats
 * Get voice performance stats
 */
router.get('/rooms/:room_name/stats', async (req, res, next) => {
  try {
    const { room_name } = req.params;

    if (!room_name || typeof room_name !== 'string') {
      return res.status(400).json({ error: 'Invalid room_name' });
    }

    const stats = liveKitService.getPerformanceStats(room_name);
    res.json(stats || {});
  } catch (error: any) {
    logError('Get voice stats error', error);
    res.status(500).json({ error: 'Failed to get voice stats' });
  }
});

/**
 * POST /voice/rooms/:room_name/stats
 * Log voice performance stats
 */
router.post('/rooms/:room_name/stats', async (req, res, next) => {
  try {
    const { room_name } = req.params;
    const stats = req.body;

    if (!room_name || typeof room_name !== 'string') {
      return res.status(400).json({ error: 'Invalid room_name' });
    }

    await liveKitService.logVoiceStats(room_name, stats);
    res.json({ success: true });
  } catch (error: any) {
    logError('Log voice stats error', error);
    res.status(500).json({ error: 'Failed to log voice stats' });
  }
});

export default router;

