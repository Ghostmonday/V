/**
 * LiveKit Token Service
 * Generates tokens for room calls with proper roles
 */

import { AccessToken } from '@livekit/server-sdk';
import { logError, logInfo } from '../shared/logger-shared.js';
import { getLiveKitKeys } from './api-keys-service.js';
import { hasEntitlement } from './entitlements.js';

/**
 * Generate LiveKit token for a room with Perfect Forward Secrecy
 * @param userId - User ID
 * @param roomId - Room ID (used as room name)
 * @param role - Participant role: 'admin' or 'guest'
 * @param callId - Optional call ID for PFS session
 * @returns JWT token string and PFS public key
 * @throws Error if user doesn't have voice entitlement
 */
export async function generateLiveKitToken(
  userId: string,
  roomId: string,
  role: 'admin' | 'guest' = 'guest',
  callId?: string
): Promise<{ token: string; pfsPublicKey?: string; pfsKeyId?: string }> {
  // Check if user has voice entitlement (pro_monthly or pro_annual)
  const hasVoiceAccess =
    (await hasEntitlement(userId, 'pro_monthly')) || (await hasEntitlement(userId, 'pro_annual'));

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

    // Generate ephemeral key pair for Perfect Forward Secrecy if callId provided
    let pfsPublicKey: string | undefined;
    let pfsKeyId: string | undefined;

    if (callId) {
      try {
        const { generateEphemeralKeyPair } = await import('./pfs-media-service.js');
        const ephemeralKeyPair = await generateEphemeralKeyPair();
        pfsPublicKey = ephemeralKeyPair.publicKey;
        pfsKeyId = ephemeralKeyPair.keyId;

        // Store private key temporarily in Redis (will be deleted after call ends)
        const redis = (await import('../config/db.ts')).getRedisClient();
        const privateKeyKey = `pfs:call:${callId}:user:${userId}:private`;
        await redis.setex(
          privateKeyKey,
          2 * 60 * 60, // 2 hours TTL
          ephemeralKeyPair.privateKey
        );

        logInfo(`PFS ephemeral key generated for call ${callId}`, { userId, keyId: pfsKeyId });
      } catch (pfsError) {
        logError(
          'Failed to generate PFS keys (non-critical)',
          pfsError instanceof Error ? pfsError : new Error(String(pfsError))
        );
        // Continue without PFS - token generation succeeds
      }
    }

    logInfo(`LiveKit token generated for user ${userId} in room ${roomId} as ${role}`, {
      pfsEnabled: !!callId,
    });

    return { token: jwt, pfsPublicKey, pfsKeyId };
  } catch (error) {
    logError(
      'Failed to generate LiveKit token',
      error instanceof Error ? error : new Error(String(error))
    );
    return { token: '' };
  }
}
