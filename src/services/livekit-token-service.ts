/**
 * LiveKit Token Service
 * Generates tokens for room calls with proper roles
 */

import { AccessToken } from '@livekit/server-sdk';
import { logError, logInfo } from '../shared/logger.js';
import { getLiveKitKeys } from './api-keys-service.js';
import { hasEntitlement } from './entitlements.js';

/**
 * Generate LiveKit token for a room
 * @param userId - User ID
 * @param roomId - Room ID (used as room name)
 * @param role - Participant role: 'admin' or 'guest'
 * @returns JWT token string
 * @throws Error if user doesn't have voice entitlement
 */
export async function generateLiveKitToken(
  userId: string,
  roomId: string,
  role: 'admin' | 'guest' = 'guest'
): Promise<string> {
  // Check if user has voice entitlement (pro_monthly or pro_annual)
  const hasVoiceAccess = await hasEntitlement(userId, 'pro_monthly') || 
                         await hasEntitlement(userId, 'pro_annual');
  
  if (!hasVoiceAccess) {
    throw new Error('Voice access requires Pro subscription. Please upgrade.');
  }
  try {
    const livekitKeys = await getLiveKitKeys();
    const apiKey = livekitKeys.apiKey;
    const apiSecret = livekitKeys.apiSecret;

    if (!apiKey || !apiSecret) {
      logError('LiveKit credentials not found in vault');
      return '';
    }

    const token = new AccessToken(apiKey, apiSecret, {
      identity: userId,
      ttl: 2 * 60 * 60, // 2 hours
    });

    // Grant permissions based on role
    const canPublish = role === 'admin';
    const canSubscribe = true;
    const canPublishData = true;

    token.addGrant({
      roomJoin: true,
      room: roomId,
      canPublish,
      canSubscribe,
      canPublishData,
    });

    const jwt = token.toJwt();
    logInfo(`LiveKit token generated for user ${userId} in room ${roomId} as ${role}`);
    return jwt;
  } catch (error) {
    logError('Failed to generate LiveKit token', error instanceof Error ? error : new Error(String(error)));
    return '';
  }
}

