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
import { findOne, upsert, create } from '../shared/supabase-helpers.js';
import { logError, logInfo } from '../shared/logger.js';
import { verifyAppleTokenWithJWKS } from './apple-jwks-verifier.js';
import { getJwtSecret, getLiveKitKeys } from './api-keys-service.js';
import { supabase } from '../shared/supabase-client.js';

const JWT_SECRET = process.env.JWT_SECRET as string;

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
    const livekitModule = await import('@livekit/server-sdk') as { TokenGenerator?: new (apiKey: string, apiSecret: string) => { createToken: (grants: unknown, options: unknown) => string } };
    const TokenGenerator = livekitModule.TokenGenerator;
    if (TokenGenerator) {
      const livekitKeys = await getLiveKitKeys();
      if (livekitKeys.apiKey && livekitKeys.apiSecret) {
        const tokenGenerator = new TokenGenerator(livekitKeys.apiKey, livekitKeys.apiSecret);
        const room = roomId || 'default';
        return tokenGenerator.createToken({ video: { roomJoin: true, room } }, { identity: userId });
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
export async function verifyAppleSignInToken(token: string, ageVerified?: boolean): Promise<{ jwt: string; livekitToken: string }> {
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
      logInfo('User record update (non-critical):', upsertError instanceof Error ? upsertError.message : String(upsertError)); // Silent fail: user creation fails but JWT still issued
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
      livekitToken: liveKitRoomToken
    };
  } catch (error: unknown) {
    logError('Apple Sign-In verification failed', error instanceof Error ? error : new Error(String(error)));
    throw new Error(error instanceof Error ? error.message : 'Failed to verify Apple authentication token');
  }
}

import { validateServiceData, validateAfterDB } from '../middleware/incremental-validation.js';
import { validatePasswordStrength } from '../middleware/password-strength.js';
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
      username: validatedCreds.username
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
      // New system: verify bcrypt hash
      isValid = await bcrypt.compare(password, user.password_hash);
    } else if (user.password) {
      // Legacy system: migrate to hash
      isValid = password === user.password;
      if (isValid) {
        // Migrate to hashed password
        const password_hash = await bcrypt.hash(password, 10);
        await upsert('users', { id: user.id, password_hash }, 'id');
        logInfo('User password migrated to hash', user.id);
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

    const applicationToken = jwt.sign(
      { userId: user.id },
      jwtSecret,
      { expiresIn: '7d' }
    );

    return { jwt: applicationToken };
  } catch (error: unknown) {
    logError('Credential authentication failed', error instanceof Error ? error : new Error(String(error)));
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
    const password_hash = await bcrypt.hash(password, 10);
    if (!password_hash || password_hash.length < 10) {
      throw new Error('Failed to hash password');
    }

    // Create user
    const userData: Record<string, unknown> = {
      username,
      password_hash,
      subscription: 'free'
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

    const applicationToken = jwt.sign(
      { userId: user.id },
      jwtSecret,
      { expiresIn: '7d' }
    );

    return { jwt: applicationToken };
  } catch (error: unknown) {
    logError('Registration failed', error instanceof Error ? error : new Error(String(error)));
    throw new Error(error instanceof Error ? error.message : 'Registration failed');
  }
}
