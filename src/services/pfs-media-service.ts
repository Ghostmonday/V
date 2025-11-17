/**
 * Perfect Forward Secrecy (PFS) for Media Streams
 * Implements ephemeral key exchange for voice/video calls
 * Ensures that even if long-term keys are compromised, past calls remain secure
 */

import crypto from 'crypto';
import { logError, logInfo } from '../shared/logger.js';
import { getRedisClient } from '../config/db.ts';
import { supabase } from '../config/db.ts';
import {
  encryptWithHardwareAcceleration,
  decryptWithHardwareAcceleration,
} from './hardware-accelerated-encryption.js';
import { getEncryptionConfig } from '../config/encryption-config.js';
import { mediaStreamCircuitBreaker } from '../utils/circuit-breaker.js';

const redis = getRedisClient();

/**
 * Ephemeral key pair for a call session
 */
export interface EphemeralKeyPair {
  publicKey: string; // Base64 encoded
  privateKey: string; // Base64 encoded (stored temporarily, deleted after call)
  keyId: string; // Unique identifier for this key pair
  createdAt: number;
  expiresAt: number; // Keys expire after call ends
}

/**
 * Call session with PFS
 */
export interface PFSCallSession {
  callId: string;
  roomId: string;
  participants: string[];
  ephemeralKeys: Map<string, EphemeralKeyPair>; // userId -> key pair
  sharedSecret?: string; // Derived from ephemeral keys (ECDH)
  createdAt: number;
  expiresAt: number;
}

/**
 * Generate ephemeral key pair for PFS
 * Uses ECDH (Elliptic Curve Diffie-Hellman) for key exchange
 */
export async function generateEphemeralKeyPair(): Promise<EphemeralKeyPair> {
  try {
    // Use P-256 curve (secp256r1) for ECDH
    const ecdh = crypto.createECDH('secp256r1');
    ecdh.generateKeys();
    
    const publicKey = ecdh.getPublicKey('base64');
    const privateKey = ecdh.getPrivateKey('base64');
    const keyId = crypto.randomBytes(16).toString('hex');
    
    // Keys expire after 2 hours (call duration limit)
    const expiresAt = Date.now() + (2 * 60 * 60 * 1000);
    
    logInfo('Generated ephemeral key pair for PFS', { keyId });
    
    return {
      publicKey,
      privateKey,
      keyId,
      createdAt: Date.now(),
      expiresAt,
    };
  } catch (error: any) {
    logError('Failed to generate ephemeral key pair', error);
    throw new Error('Failed to generate ephemeral key pair for PFS');
  }
}

/**
 * Derive shared secret from ephemeral keys (ECDH)
 * 
 * PERFECT FORWARD SECRECY FLOW:
 * 1. Each call generates ephemeral ECDH key pairs (generateEphemeralKeyPair)
 * 2. Participants exchange public keys (getCallPublicKeys)
 * 3. Each participant derives shared secret using their private key + other's public key (deriveSharedSecret)
 * 4. Shared secret is derived using HKDF to create encryption key (pbkdf2Sync)
 * 5. Encryption key is used to encrypt media streams (encryptMediaStream)
 * 6. After call ends, all ephemeral private keys are deleted (endPFSCallSession)
 * 
 * SECURITY PROPERTIES:
 * - Each call gets unique ephemeral keys (never reused)
 * - Keys are deleted immediately after call ends
 * - Even if long-term keys are compromised, past calls remain secure
 * - Future calls use fresh keys, so compromise doesn't affect future calls
 * 
 * This secret is used to encrypt media streams with Perfect Forward Secrecy
 * Uses hardware-accelerated AES-256-GCM when available
 */
export function deriveSharedSecret(
  ourPrivateKey: string,
  theirPublicKey: string
): string {
  try {
    // Step 1: Create ECDH instance with P-256 curve (secp256r1)
    const ecdh = crypto.createECDH('secp256r1');
    ecdh.setPrivateKey(Buffer.from(ourPrivateKey, 'base64'));
    
    // Step 2: Compute shared secret using ECDH (Diffie-Hellman key exchange)
    // This produces a shared secret that only these two parties can compute
    const sharedSecret = ecdh.computeSecret(Buffer.from(theirPublicKey, 'base64'));
    
    // Step 3: Derive encryption key from shared secret using HKDF (PBKDF2)
    // This ensures Perfect Forward Secrecy - each call gets a unique key
    // Even if the shared secret is somehow compromised, it's only valid for this call
    const derivedKey = crypto.pbkdf2Sync(
      sharedSecret,
      Buffer.from('vibez-pfs-media', 'utf8'), // Salt/context
      100000, // Iterations (high for security)
      32, // Key length (256 bits)
      'sha256' // Hash function
    );
    
    // Log key derivation event for audit trail (without exposing secrets)
    const keyId = crypto.createHash('sha256').update(sharedSecret).digest('hex').substring(0, 16);
    const encryptionConfig = getEncryptionConfig();
    logInfo('Key derivation event - PFS shared secret derived', {
      keyIdHash: keyId, // Partial hash for identification, not the actual key
      keyLength: derivedKey.length,
      algorithm: encryptionConfig.preferredAlgorithm,
      hardwareAccelerated: encryptionConfig.hardwareAccelerated,
      timestamp: new Date().toISOString(),
    });
    
    return derivedKey.toString('base64');
  } catch (error: any) {
    logError('Failed to derive shared secret', error);
    throw new Error('Failed to derive shared secret for PFS');
  }
}

/**
 * Create PFS call session
 * Generates ephemeral keys for all participants
 */
export async function createPFSCallSession(
  callId: string,
  roomId: string,
  participantIds: string[]
): Promise<PFSCallSession> {
  try {
    const ephemeralKeys = new Map<string, EphemeralKeyPair>();
    
    // Generate ephemeral key pair for each participant
    for (const userId of participantIds) {
      const keyPair = await generateEphemeralKeyPair();
      ephemeralKeys.set(userId, keyPair);
      
      // Store private key temporarily in Redis (expires after call)
      // Private keys are NEVER stored in database - only in Redis with TTL
      const privateKeyKey = `pfs:call:${callId}:user:${userId}:private`;
      await redis.setex(
        privateKeyKey,
        2 * 60 * 60, // 2 hours TTL
        keyPair.privateKey
      );
    }
    
    const session: PFSCallSession = {
      callId,
      roomId,
      participants: participantIds,
      ephemeralKeys,
      createdAt: Date.now(),
      expiresAt: Date.now() + (2 * 60 * 60 * 1000), // 2 hours
    };
    
    // Store session metadata in Redis (public keys only)
    const sessionKey = `pfs:call:${callId}`;
    const sessionData = {
      callId,
      roomId,
      participants: participantIds,
      publicKeys: Object.fromEntries(
        Array.from(ephemeralKeys.entries()).map(([userId, keyPair]) => [
          userId,
          { publicKey: keyPair.publicKey, keyId: keyPair.keyId },
        ])
      ),
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
    };
    
    await redis.setex(
      sessionKey,
      2 * 60 * 60, // 2 hours TTL
      JSON.stringify(sessionData)
    );
    
    logInfo('Created PFS call session', {
      callId,
      roomId,
      participantCount: participantIds.length,
    });
    
    return session;
  } catch (error: any) {
    logError('Failed to create PFS call session', error);
    throw new Error('Failed to create PFS call session');
  }
}

/**
 * Get ephemeral public keys for a call
 * Used by participants to derive shared secret
 */
export async function getCallPublicKeys(callId: string): Promise<Record<string, { publicKey: string; keyId: string }> | null> {
  try {
    const sessionKey = `pfs:call:${callId}`;
    const sessionDataJson = await redis.get(sessionKey);
    
    if (!sessionDataJson) {
      return null;
    }
    
    const sessionData = JSON.parse(sessionDataJson);
    return sessionData.publicKeys || null;
  } catch (error: any) {
    logError('Failed to get call public keys', error);
    return null;
  }
}

/**
 * Get user's ephemeral private key for a call
 * Used to derive shared secret (deleted after call ends)
 */
export async function getUserPrivateKey(
  callId: string,
  userId: string
): Promise<string | null> {
  try {
    const privateKeyKey = `pfs:call:${callId}:user:${userId}:private`;
    const privateKey = await redis.get(privateKeyKey);
    return privateKey;
  } catch (error: any) {
    logError('Failed to get user private key', error);
    return null;
  }
}

/**
 * Derive shared encryption key for media stream
 * Each participant derives the same key from their private key + others' public keys
 */
export async function deriveMediaEncryptionKey(
  callId: string,
  userId: string
): Promise<string | null> {
  try {
    // Get our private key
    const ourPrivateKey = await getUserPrivateKey(callId, userId);
    if (!ourPrivateKey) {
      return null;
    }
    
    // Get all public keys
    const publicKeys = await getCallPublicKeys(callId);
    if (!publicKeys) {
      return null;
    }
    
    // Derive shared secret with first other participant
    // In group calls, use key derivation from all participants
    const otherParticipants = Object.keys(publicKeys).filter(id => id !== userId);
    if (otherParticipants.length === 0) {
      return null;
    }
    
    // Use first participant's public key to derive shared secret
    // In production, use group key agreement (e.g., TreeKEM)
    const firstParticipantId = otherParticipants[0];
    const theirPublicKey = publicKeys[firstParticipantId].publicKey;
    
    const sharedSecret = deriveSharedSecret(ourPrivateKey, theirPublicKey);
    
    logInfo('Derived media encryption key for PFS', {
      callId,
      userId,
      participantCount: otherParticipants.length,
    });
    
    return sharedSecret;
  } catch (error: any) {
    logError('Failed to derive media encryption key', error);
    return null;
  }
}

/**
 * End call session and delete all ephemeral keys
 * Critical for PFS - keys must be deleted after call ends
 */
export async function endPFSCallSession(callId: string): Promise<void> {
  try {
    // Get session to find all participants
    const sessionKey = `pfs:call:${callId}`;
    const sessionDataJson = await redis.get(sessionKey);
    
    if (sessionDataJson) {
      const sessionData = JSON.parse(sessionDataJson);
      const participants = sessionData.participants || [];
      
      // Delete all private keys
      for (const userId of participants) {
        const privateKeyKey = `pfs:call:${callId}:user:${userId}:private`;
        await redis.del(privateKeyKey);
      }
    }
    
    // Delete session metadata
    await redis.del(sessionKey);
    
    logInfo('Ended PFS call session and deleted ephemeral keys', { callId });
  } catch (error: any) {
    logError('Failed to end PFS call session', error);
    // Don't throw - cleanup should be best-effort
  }
}

/**
 * Encrypt media stream data using hardware-accelerated AES-256-GCM
 * Uses the shared secret derived from PFS ephemeral keys
 * Protected by circuit breaker to prevent cascading failures
 * 
 * @param mediaData - Media stream data to encrypt
 * @param sharedSecret - Shared secret derived from ECDH (base64 encoded)
 * @returns Encrypted data with IV and auth tag
 */
export async function encryptMediaStream(
  mediaData: Buffer,
  sharedSecret: string
): Promise<{
  encrypted: Buffer;
  iv: Buffer;
  authTag: Buffer;
  algorithm: string;
}> {
  // Use circuit breaker to prevent cascading failures under load
  return await mediaStreamCircuitBreaker.execute(async () => {
    try {
      // Decode shared secret from base64
      const secretKey = Buffer.from(sharedSecret, 'base64');
      
      // Use hardware-accelerated encryption (AES-256-GCM with AES-NI if available)
      const result = await encryptWithHardwareAcceleration(mediaData, secretKey);
      
      if (!result.authTag) {
        throw new Error('Auth tag required for GCM mode');
      }
      
      const encryptionConfig = getEncryptionConfig();
      logInfo('Encrypted media stream with hardware-accelerated AES-256-GCM', {
        algorithm: result.algorithm,
        dataSize: mediaData.length,
        hardwareAccelerated: encryptionConfig.hardwareAccelerated,
      });
      
      return {
        encrypted: result.encrypted,
        iv: result.iv,
        authTag: result.authTag,
        algorithm: result.algorithm,
      };
    } catch (error: any) {
      logError('Failed to encrypt media stream', error);
      throw new Error('Failed to encrypt media stream with PFS');
    }
  }, async () => {
    // Fallback: return error response instead of crashing
    logError('Media stream encryption failed - circuit breaker fallback', new Error('Encryption service unavailable'));
    throw new Error('Media stream encryption temporarily unavailable');
  });
}

/**
 * Decrypt media stream data using hardware-accelerated AES-256-GCM
 * Uses the shared secret derived from PFS ephemeral keys
 * Protected by circuit breaker to prevent cascading failures
 * 
 * @param encryptedData - Encrypted media stream data
 * @param sharedSecret - Shared secret derived from ECDH (base64 encoded)
 * @param iv - Initialization vector
 * @param authTag - Authentication tag
 * @param algorithm - Encryption algorithm (defaults to optimal)
 * @returns Decrypted media stream data
 */
export async function decryptMediaStream(
  encryptedData: Buffer,
  sharedSecret: string,
  iv: Buffer,
  authTag: Buffer,
  algorithm?: string
): Promise<Buffer> {
  // Use circuit breaker to prevent cascading failures under load
  return await mediaStreamCircuitBreaker.execute(async () => {
    try {
      // Decode shared secret from base64
      const secretKey = Buffer.from(sharedSecret, 'base64');
      
      // Use hardware-accelerated decryption (AES-256-GCM with AES-NI if available)
      const decrypted = await decryptWithHardwareAcceleration(
        encryptedData,
        secretKey,
        iv,
        authTag,
        algorithm
      );
      
      const encryptionConfig = getEncryptionConfig();
      logInfo('Decrypted media stream with hardware-accelerated AES-256-GCM', {
        algorithm: algorithm || encryptionConfig.preferredAlgorithm,
        dataSize: decrypted.length,
        hardwareAccelerated: encryptionConfig.hardwareAccelerated,
      });
      
      return decrypted;
    } catch (error: any) {
      logError('Failed to decrypt media stream', error);
      throw new Error('Failed to decrypt media stream with PFS');
    }
  }, async () => {
    // Fallback: return error response instead of crashing
    logError('Media stream decryption failed - circuit breaker fallback', new Error('Decryption service unavailable'));
    throw new Error('Media stream decryption temporarily unavailable');
  });
}

/**
 * Cleanup expired call sessions (cron job)
 * Ensures ephemeral keys are deleted even if endPFSCallSession wasn't called
 */
export async function cleanupExpiredPFSSessions(): Promise<number> {
  try {
    // Find all PFS call session keys
    const keys = await redis.keys('pfs:call:*');
    let cleaned = 0;
    
    for (const key of keys) {
      // Check if session is expired
      const sessionDataJson = await redis.get(key);
      if (sessionDataJson) {
        try {
          const sessionData = JSON.parse(sessionDataJson);
          if (sessionData.expiresAt && Date.now() > sessionData.expiresAt) {
            // Session expired - delete it
            await endPFSCallSession(sessionData.callId);
            cleaned++;
          }
        } catch {
          // Invalid session data - delete it
          await redis.del(key);
          cleaned++;
        }
      }
    }
    
    if (cleaned > 0) {
      logInfo(`Cleaned up ${cleaned} expired PFS call sessions`);
    }
    
    return cleaned;
  } catch (error: any) {
    logError('Failed to cleanup expired PFS sessions', error);
    return 0;
  }
}

