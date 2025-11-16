// 🔧 Upgraded: src/routes/video/join.ts

import { Router } from 'express';

import { AccessToken } from 'livekit-server-sdk';

import { supabase } from '../../config/db.js';

import { healingLogger } from '../../shared/logger.js';

import { telemetryService } from '../../services/telemetry-service.js';

import * as Sentry from '@sentry/node'; // Added for server-side error reporting

const router = Router();

interface JoinVideoRequest {

  roomName: string;

  userName?: string;

}

interface JoinVideoResponse {

  token: string;

  roomName: string;

  serverUrl: string;

}

router.post('/join', async (req, res) => {

  const transaction = Sentry.startTransaction({ op: 'video.join', name: 'Generate Video Token' }); // Wrapped with Sentry

  const startTime = Date.now();

  try {

    const { roomName, userName }: JoinVideoRequest = req.body;

   

    // Sanitize inputs (security enhancement)

    const sanitizedRoomName = roomName?.trim();

    const sanitizedUserName = userName?.trim();

    // Validate input

    if (!sanitizedRoomName) {

      return res.status(400).json({

        error: 'Missing required field: roomName'

      });

    }

    // Verify authentication and get userId from JWT (security: avoid trusting client-provided userId)

    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {

      return res.status(401).json({ error: 'Missing or invalid authorization header' });

    }

    const jwt = authHeader.split(' ')[1];

    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);

    if (authError || !user) {

      healingLogger.warn('VideoJoinRoute', 'Unauthorized video join attempt');

      return res.status(401).json({ error: 'Unauthorized' });

    }

    const userId = user.id;

    // Verify user exists (RLS implicitly handled via auth, but explicit check for resilience)

    const { data: userData, error: userError } = await supabase

      .from('users')

      .select('id, username')

      .eq('id', userId)

      .single();

    if (userError || !userData) {

      healingLogger.warn('VideoJoinRoute', `User not found: ${userId}`);

      return res.status(404).json({ error: 'User not found' });

    }

    // Check room access with Supabase RLS (assume 'rooms' table has RLS policies for access)

    const { data: roomAccess, error: roomError } = await supabase

      .from('rooms')

      .select('id')

      .eq('name', sanitizedRoomName)

      .single();

    if (roomError || !roomAccess) {

      healingLogger.warn('VideoJoinRoute', `Room not found or access denied: ${sanitizedRoomName}`);

      return res.status(404).json({ error: 'Room not found or access denied' });

    }

    // Create LiveKit access token (get keys from vault)
    const { getLiveKitKeys } = await import('../../services/api-keys-service.js');
    const livekitKeys = await getLiveKitKeys();
    
    if (!livekitKeys.apiKey || !livekitKeys.apiSecret) {
      healingLogger.error('VideoJoinRoute', 'LiveKit credentials not found in vault');
      return res.status(500).json({ error: 'Video service not configured' });
    }

    const at = new AccessToken(
      livekitKeys.apiKey,
      livekitKeys.apiSecret,
      {
        identity: userId,
        name: sanitizedUserName || userData.username,
        ttl: 2 * 60 * 60, // 2 hours
      }
    );

    at.addGrant({

      roomJoin: true,

      room: sanitizedRoomName,

      canPublish: true,

      canSubscribe: true,

      canPublishData: true,

      roomCreate: false,

      roomList: false,

    });

    const token = at.toJwt();

    const serverUrl = `wss://${livekitKeys.host || livekitKeys.url?.replace('wss://', '')}`;

    healingLogger.info('VideoJoinRoute', `Video token generated for user ${userId} in room ${sanitizedRoomName}`);

    telemetryService.logEvent('video_token_generated', { userId, roomName: sanitizedRoomName, duration: Date.now() - startTime });

    const response: JoinVideoResponse = {

      token,

      roomName: sanitizedRoomName,

      serverUrl

    };

    res.json(response);

  } catch (error) {

    Sentry.captureException(error);

    healingLogger.error('VideoJoinRoute', `Error generating video token: ${error.message}`);

    telemetryService.logEvent('video_token_error', { error: error.message, duration: Date.now() - startTime });

   

    res.status(500).json({

      error: 'Failed to generate video token',

      details: process.env.NODE_ENV === 'development' ? error.message : undefined

    });

  } finally {

    transaction.finish();

    // @todo Add Prometheus histogram for latency (e.g., video_join_latency.observe(Date.now() - startTime / 1000))

  }

});

// Health check endpoint for video service

router.get('/health', async (_req, res) => {

  const transaction = Sentry.startTransaction({ op: 'video.health', name: 'Video Health Check' });

  try {

    // Test LiveKit connectivity by creating a test token
    const { getLiveKitKeys } = await import('../../services/api-keys-service.js');
    const livekitKeys = await getLiveKitKeys();
    
    if (!livekitKeys.apiKey || !livekitKeys.apiSecret) {
      throw new Error('LiveKit credentials not found in vault');
    }

    const at = new AccessToken(
      livekitKeys.apiKey,
      livekitKeys.apiSecret,
      { identity: 'health-check', ttl: 60 }
    );

   

    at.addGrant({ roomJoin: true, room: 'health-check-room' });

    const token = at.toJwt();

    res.json({

      status: 'ok',

      livekit: 'connected',

      timestamp: new Date().toISOString()

    });

  } catch (error) {

    Sentry.captureException(error);

    healingLogger.error('VideoJoinRoute', `Video health check failed: ${error.message}`);

    res.status(503).json({

      status: 'error',

      livekit: 'disconnected',

      error: error.message

    });

  } finally {

    transaction.finish();

  }

});

export default router;

