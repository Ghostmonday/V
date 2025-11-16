/**
 * Apple JWKS Token Verifier - Real Implementation
 * Verifies Apple ID tokens using Apple's JSON Web Key Set (JWKS)
 * Uses jose library for proper JWK handling
 */

import { jwtVerify, createRemoteJWKSet } from 'jose';
import { logError, logInfo } from '../shared/logger.js';
import { getAppleKeys } from './api-keys-service.js';

const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys';
const JWKS = createRemoteJWKSet(new URL(APPLE_KEYS_URL));

/**
 * Verify Apple ID token using JWKS
 * @param token - Apple ID token (JWT)
 * @returns Decoded token payload with verified signature
 */
export async function verifyAppleTokenWithJWKS(token: string): Promise<any> {
  try {
    if (!token) {
      throw new Error('Apple token is required');
    }

    // Get Apple keys from database vault
    const appleKeys = await getAppleKeys();
    const serviceId = appleKeys.serviceId || appleKeys.clientId;
    const teamId = appleKeys.teamId;

    if (!serviceId) {
      throw new Error('APPLE_SERVICE_ID or APPLE_CLIENT_ID must be set in vault');
    }

    // Verify token signature and claims using jose library
    // This properly handles JWK to PEM conversion and signature verification
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: 'https://appleid.apple.com',
      audience: [serviceId, `com.${teamId}.${serviceId}`].filter(Boolean),
    });

    logInfo('Apple token verified successfully', { sub: payload.sub });
    return payload;
  } catch (error) {
    logError('Apple JWKS verification failed', error instanceof Error ? error : new Error(String(error)));
    throw new Error(error instanceof Error ? error.message : 'Failed to verify Apple token');
  }
}
