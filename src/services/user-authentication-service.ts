/**
 * User Authentication Service
 * Handles Apple Sign-In verification, username/password login, and JWT token generation
 *
 * New simplified functions:
 * - authenticate(email, password) - Supabase email/password authentication
 * - issueToken(user) - Simple JWT token generation
 *
 * Legacy functions (kept for backward compatibility):
 * - verifyAppleSignInToken() - Apple Sign-In
 * - authenticateWithCredentials() - Username/password (legacy)
 * - registerUser() - User registration
 */

import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import argon2 from 'argon2';
import { createCipheriv, createDecipheriv, randomBytes, scrypt } from 'crypto';
import { promisify } from 'util';
import { findOne, upsert, create } from '../shared/supabase-helpers.js';
import { logError, logInfo } from '../shared/logger.js';
import { verifyAppleTokenWithJWKS } from './apple-jwks-verifier.js';
import { getJwtSecret, getLiveKitKeys, getApiKey } from './api-keys-service.js';
import { supabase } from '../shared/supabase-client.js';

const JWT_SECRET = process.env.JWT_SECRET as string;

// AES-256-GCM encryption configuration
const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12; // 96 bits for GCM
const SALT_LENGTH = 16;
const TAG_LENGTH = 16;

// Cache for encryption key (derived from vault key)
let encryptionKeyCache: Buffer | null = null;
let encryptionKeyPromise: Promise<Buffer> | null = null;

/**
 * Get encryption key from vault
 * Derives a 32-byte key using scrypt from the master encryption key
 */
async function getEncryptionKey(): Promise<Buffer> {
  if (encryptionKeyCache) {
    return encryptionKeyCache;
  }

  if (encryptionKeyPromise) {
    return encryptionKeyPromise;
  }

  encryptionKeyPromise = (async () => {
    try {
      // Get master encryption key from vault
      const masterKey = await getApiKey('ENCRYPTION_MASTER_KEY', 'production').catch(() => {
        // Fallback to environment variable if vault not available
        return process.env.ENCRYPTION_MASTER_KEY || '';
      });

      if (!masterKey) {
        throw new Error('ENCRYPTION_MASTER_KEY not found in vault or environment');
      }

      // Derive 32-byte key using scrypt
      const scryptAsync = promisify(scrypt);
      const salt = Buffer.from('vibez-encryption-salt', 'utf8'); // Fixed salt for consistency
      const derivedKey = (await scryptAsync(masterKey, salt, 32)) as Buffer;

      encryptionKeyCache = derivedKey;
      return derivedKey;
    } catch (error) {
      logError(
        'Failed to get encryption key',
        error instanceof Error ? error : new Error(String(error))
      );
      throw error;
    }
  })();

  return encryptionKeyPromise;
}

/**
 * Encrypt sensitive data using AES-256-GCM
 * @param plaintext - Data to encrypt
 * @returns Encrypted data as base64 string (format: iv:tag:encrypted)
 */
export async function encryptSensitiveData(plaintext: string): Promise<string> {
  try {
    const key = await getEncryptionKey();
    const iv = randomBytes(IV_LENGTH);

    const cipher = createCipheriv(ALGORITHM, key, iv);
    let encrypted = cipher.update(plaintext, 'utf8');
    encrypted = Buffer.concat([encrypted, cipher.final()]);

    const tag = cipher.getAuthTag();

    // Combine IV, tag, and encrypted data
    const combined = Buffer.concat([iv, tag, encrypted]);
    return combined.toString('base64');
  } catch (error) {
    logError('Encryption failed', error instanceof Error ? error : new Error(String(error)));
    throw new Error('Failed to encrypt sensitive data');
  }
}

/**
 * Decrypt sensitive data using AES-256-GCM
 * @param encryptedData - Encrypted data as base64 string
 * @returns Decrypted plaintext
 */
export async function decryptSensitiveData(encryptedData: string): Promise<string> {
  try {
    const key = await getEncryptionKey();
    const combined = Buffer.from(encryptedData, 'base64');

    // Extract IV, tag, and encrypted data
    const iv = combined.subarray(0, IV_LENGTH);
    const tag = combined.subarray(IV_LENGTH, IV_LENGTH + TAG_LENGTH);
    const encrypted = combined.subarray(IV_LENGTH + TAG_LENGTH);

    const decipher = createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(tag);

    let decrypted = decipher.update(encrypted);
    decrypted = Buffer.concat([decrypted, decipher.final()]);

    return decrypted.toString('utf8');
  } catch (error) {
    logError('Decryption failed', error instanceof Error ? error : new Error(String(error)));
    throw new Error('Failed to decrypt sensitive data');
  }
}

/**
 * Encrypt user email for storage
 * @param email - Email address to encrypt
 * @returns Encrypted email
 */
export async function encryptUserEmail(email: string): Promise<string> {
  return encryptSensitiveData(email.toLowerCase().trim());
}

/**
 * Decrypt user email from storage
 * @param encryptedEmail - Encrypted email
 * @returns Decrypted email
 */
export async function decryptUserEmail(encryptedEmail: string): Promise<string> {
  return decryptSensitiveData(encryptedEmail);
}

/**
 * Encrypt user phone number for storage
 * @param phone - Phone number to encrypt
 * @returns Encrypted phone
 */
export async function encryptUserPhone(phone: string): Promise<string> {
  // Normalize phone number before encryption
  const normalized = phone.replace(/\D/g, '');
  return encryptSensitiveData(normalized);
}

/**
 * Decrypt user phone number from storage
 * @param encryptedPhone - Encrypted phone
 * @returns Decrypted phone
 */
export async function decryptUserPhone(encryptedPhone: string): Promise<string> {
  return decryptSensitiveData(encryptedPhone);
}

/**
 * NEW: Authenticate user with email and password using Supabase Auth
 * Returns user object with id, tier, and handle
 */
export async function authenticate(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  if (error || !data.user) throw new Error('Invalid credentials');

  const user = data.user;

  return { id: user.id, tier: 'free', handle: 'default' }; // Stub tier/handle for MVP
}

/**
 * NEW: Issue JWT token for authenticated user
 * Uses JWT_SECRET from environment variable
 */
export function issueToken(user: { id: string; tier?: string; handle?: string }) {
  if (!JWT_SECRET) {
    throw new Error('JWT_SECRET is not set');
  }
  // Short-lived access token: 15 minutes (refresh token handles long-term auth)
  return jwt.sign(user, JWT_SECRET, { expiresIn: '15m' });
}

// LiveKit token generation helper (optional - requires @livekit/server-sdk package)
async function createLiveKitToken(userId: string, roomId?: string): Promise<string> {
  try {
    const livekitModule = (await import('@livekit/server-sdk')) as {
      TokenGenerator?: new (
        apiKey: string,
        apiSecret: string
      ) => { createToken: (grants: unknown, options: unknown) => string };
    };
    const TokenGenerator = livekitModule.TokenGenerator;
    if (TokenGenerator) {
      const livekitKeys = await getLiveKitKeys();
      if (livekitKeys.apiKey && livekitKeys.apiSecret) {
        const tokenGenerator = new TokenGenerator(livekitKeys.apiKey, livekitKeys.apiSecret);
        const room = roomId || 'default';
        return tokenGenerator.createToken(
          { video: { roomJoin: true, room } },
          { identity: userId }
        );
      }
    }
  } catch {
    logInfo('LiveKit SDK not available - video token generation disabled');
  }
  return '';
}

/**
 * Verify Apple ID token using Apple's JWKS and create user session
 * Returns JWT token and LiveKit room token
 */
export async function verifyAppleSignInToken(
  token: string,
  ageVerified?: boolean
): Promise<{ jwt: string; livekitToken: string }> {
  try {
    if (!token) {
      throw new Error('Apple authentication token is required');
    }

    // Verify Apple ID token using JWKS
    const payload = await verifyAppleTokenWithJWKS(token);

    const appleUserId = payload.sub;

    // Create or update user record with age verification
    try {
      const userData: Record<string, unknown> = { id: appleUserId };
      if (ageVerified !== undefined) {
        userData.age_verified = ageVerified;
      }
      await upsert('users', userData, 'id'); // Race: concurrent sign-ins can conflict
    } catch (upsertError: unknown) {
      // Non-critical: user might already exist
      logInfo(
        'User record update (non-critical):',
        upsertError instanceof Error ? upsertError.message : String(upsertError)
      ); // Silent fail: user creation fails but JWT still issued
    }

    // Generate application JWT token (from vault)
    const jwtSecret = await getJwtSecret();
    if (!jwtSecret) {
      throw new Error('JWT_SECRET not found in vault');
    }

    const applicationToken = jwt.sign(
      { userId: appleUserId },
      jwtSecret,
      { expiresIn: '7d' } // JWT renewal: no refresh token, user must re-auth after 7 days
    );

    // Generate LiveKit room token for video calls (if available)
    const liveKitRoomToken = await createLiveKitToken(appleUserId);

    return {
      jwt: applicationToken,
      livekitToken: liveKitRoomToken,
    };
  } catch (error: unknown) {
    logError(
      'Apple Sign-In verification failed',
      error instanceof Error ? error : new Error(String(error))
    );
    throw new Error(
      error instanceof Error ? error.message : 'Failed to verify Apple authentication token'
    );
  }
}

import { validateServiceData, validateAfterDB } from '../middleware/validation/incremental-validation.js';
import { validatePasswordStrength } from '../middleware/validation/password-strength.js';
import { z } from 'zod';

// Validation schemas
const credentialsSchema = z.object({
  username: z.string().min(1).max(100),
  password: z.string().min(1).max(500), // Max length for bcrypt
});

const userSchema = z.object({
  id: z.string().uuid(),
  password_hash: z.string().optional(),
  password: z.string().optional(),
});

/**
 * Authenticate user with username and password
 * Returns JWT token for the authenticated user
 * Validates incrementally at every step
 */
export async function authenticateWithCredentials(
  username: string,
  password: string
): Promise<{ jwt: string }> {
  try {
    // VALIDATION POINT 1: Validate input credentials
    const validatedCreds = validateServiceData(
      { username, password },
      credentialsSchema,
      'authenticateWithCredentials'
    );

    // VALIDATION POINT 2: Validate username format (no special chars)
    if (!/^[a-zA-Z0-9_-]+$/.test(validatedCreds.username)) {
      throw new Error('Invalid username format');
    }

    const user = await findOne<{ id: string; password_hash?: string; password?: string }>('users', {
      username: validatedCreds.username,
    });

    // VALIDATION POINT 3: Validate user exists
    if (!user) {
      throw new Error('Invalid username or password');
    }

    // VALIDATION POINT 4: Validate user structure from DB
    const validatedUser = validateAfterDB(user, userSchema, 'users.findByUsername');

    // Check if user has password_hash (new system) or password (legacy)
    let isValid = false;
    if (user.password_hash) {
      // New system: verify hash (supports both bcrypt and argon2)
      if (user.password_hash.startsWith('$argon2')) {
        // Argon2 hash
        isValid = await argon2.verify(user.password_hash, password);
      } else if (user.password_hash.startsWith('$2')) {
        // Bcrypt hash
        isValid = await bcrypt.compare(password, user.password_hash);
      } else {
        // Unknown hash format - try bcrypt first
        isValid = await bcrypt.compare(password, user.password_hash).catch(() => false);
      }
    } else if (user.password) {
      // Legacy system: migrate to hash (use argon2 for new passwords)
      isValid = password === user.password;
      if (isValid) {
        // Migrate to argon2 hash (more secure)
        const password_hash = await argon2.hash(password, {
          type: argon2.argon2id,
          memoryCost: 65536, // 64 MB
          timeCost: 3,
          parallelism: 4,
        });
        await upsert('users', { id: user.id, password_hash }, 'id');
        logInfo('User password migrated to argon2 hash', user.id);
      }
    } else {
      throw new Error('Invalid username or password');
    }

    if (!isValid) {
      throw new Error('Invalid username or password');
    }

    // Get JWT secret from vault
    const jwtSecret = await getJwtSecret();
    if (!jwtSecret) {
      throw new Error('JWT_SECRET not found in vault');
    }

    const applicationToken = jwt.sign({ userId: user.id }, jwtSecret, { expiresIn: '7d' });

    return { jwt: applicationToken };
  } catch (error: unknown) {
    logError(
      'Credential authentication failed',
      error instanceof Error ? error : new Error(String(error))
    );
    throw new Error(error instanceof Error ? error.message : 'Login failed');
  }
}

/**
 * Register a new user with username and password
 * Returns JWT token for the new user
 */
export async function registerUser(
  username: string,
  password: string,
  ageVerified?: boolean
): Promise<{ jwt: string }> {
  try {
    // VALIDATION CHECKPOINT: Validate password strength
    const passwordStrength = validatePasswordStrength(password);
    if (!passwordStrength.valid) {
      throw new Error(`Password does not meet requirements: ${passwordStrength.errors.join(', ')}`);
    }

    // VALIDATION CHECKPOINT: Validate username format
    if (!/^[a-zA-Z0-9_-]+$/.test(username)) {
      throw new Error('Username can only contain letters, numbers, underscores, and hyphens');
    }

    // Check if user already exists
    const existingUser = await findOne('users', { username });
    if (existingUser) {
      throw new Error('Username already exists');
    }

    // VALIDATION CHECKPOINT: Validate password hash generation
    // Use argon2 for new passwords (more secure than bcrypt)
    const password_hash = await argon2.hash(password, {
      type: argon2.argon2id,
      memoryCost: 65536, // 64 MB
      timeCost: 3,
      parallelism: 4,
    });
    if (!password_hash || !password_hash.startsWith('$argon2')) {
      throw new Error('Failed to hash password');
    }

    // Create user
    const userData: Record<string, unknown> = {
      username,
      password_hash,
      subscription: 'free',
    };
    if (ageVerified !== undefined) {
      userData.age_verified = ageVerified;
    }
    const user = await create('users', userData);

    // Get JWT secret from vault
    const jwtSecret = await getJwtSecret();
    if (!jwtSecret) {
      throw new Error('JWT_SECRET not found in vault');
    }

    const applicationToken = jwt.sign({ userId: user.id }, jwtSecret, { expiresIn: '7d' });

    return { jwt: applicationToken };
  } catch (error: unknown) {
    logError('Registration failed', error instanceof Error ? error : new Error(String(error)));
    throw new Error(error instanceof Error ? error.message : 'Registration failed');
  }
}
