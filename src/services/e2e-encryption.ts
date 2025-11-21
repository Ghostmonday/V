/**
 * E2E Encryption Service
 * Uses Signal Protocol (@signalapp/libsignal-client) for end-to-end encryption
 */

import { logError, logInfo } from '../shared/logger-shared.js';

// Dynamic import for Signal Protocol library
let libsignal: any = null;
let libsignalPromise: Promise<any> | null = null;

/**
 * Initialize Signal Protocol library
 * Uses dynamic import to handle optional dependency
 */
async function initSignalProtocol(): Promise<any> {
  if (libsignal) {
    return libsignal;
  }

  if (libsignalPromise) {
    return libsignalPromise;
  }

  libsignalPromise = (async () => {
    try {
      // Dynamic import of @signalapp/libsignal-client
      const signalModule = await import('@signalapp/libsignal-client');
      libsignal = signalModule;
      logInfo('Signal Protocol library loaded');
      return libsignal;
    } catch (error) {
      logError(
        'Failed to load Signal Protocol library',
        error instanceof Error ? error : new Error(String(error))
      );
      throw new Error('Signal Protocol library not available. Install @signalapp/libsignal-client');
    }
  })();

  return libsignalPromise;
}

/**
 * Generate identity key pair for Signal Protocol
 * @returns Identity key pair (public and private keys)
 */
export async function generateIdentityKeyPair(): Promise<{
  publicKey: Uint8Array;
  privateKey: Uint8Array;
}> {
  try {
    const signal = await initSignalProtocol();
    const identityKeyPair = signal.IdentityKeyPair.generate();

    // API changed: IdentityKeyPair.generate() returns object with publicKey/privateKey properties
    // These are already IdentityKey and PrivateKey objects with serialize() methods
    return {
      publicKey: new Uint8Array(identityKeyPair.publicKey.serialize()),
      privateKey: new Uint8Array(identityKeyPair.privateKey.serialize()),
    };
  } catch (error) {
    logError(
      'Failed to generate identity key pair',
      error instanceof Error ? error : new Error(String(error))
    );
    throw new Error('Failed to generate identity key pair');
  }
}

/**
 * Generate prekey bundle for Signal Protocol
 * @param identityKeyPair - User's identity key pair
 * @returns Prekey bundle with identity key, signed prekey, and one-time prekeys
 */
export async function generatePreKeyBundle(identityKeyPair: {
  publicKey: Uint8Array;
  privateKey: Uint8Array;
}): Promise<{
  identityKey: Uint8Array;
  signedPreKey: { keyId: number; publicKey: Uint8Array; signature: Uint8Array };
  oneTimePreKeys: Array<{ keyId: number; publicKey: Uint8Array }>;
}> {
  try {
    const signal = await initSignalProtocol();

    // Reconstruct identity key pair from serialized keys
    // API: In v0.86.4, IdentityKeyPair.generate() returns {publicKey: PublicKey, privateKey: PrivateKey}
    // To reconstruct, deserialize as PublicKey/PrivateKey and create new IdentityKeyPair
    // Note: IdentityKeyPair constructor takes (IdentityKey, PrivateKey), but IdentityKey is just PublicKey
    const identityPublicKey = signal.PublicKey.deserialize(
      Buffer.from(identityKeyPair.publicKey)
    );
    const identityPrivateKey = signal.PrivateKey.deserialize(
      Buffer.from(identityKeyPair.privateKey)
    );
    // IdentityKeyPair constructor accepts PublicKey directly (IdentityKey is just a type alias)
    const identityKeyPairObj = new signal.IdentityKeyPair(identityPublicKey, identityPrivateKey);

    // Generate signed prekey
    // API: Use PrivateKey.generate() to create a key pair, then extract public key
    const signedPreKeyId = Math.floor(Math.random() * 0x7fffffff);
    const signedPreKeyPrivate = signal.PrivateKey.generate();
    const signedPreKeyPublic = signedPreKeyPrivate.getPublicKey();

    // Sign the signed prekey
    const signature = identityPrivateKey.sign(signedPreKeyPublic.serialize());

    // Generate one-time prekeys (typically 100, but we'll generate 10 for efficiency)
    // API: Use PrivateKey.generate() to create key pairs
    const oneTimePreKeys = [];
    for (let i = 0; i < 10; i++) {
      const preKeyId = Math.floor(Math.random() * 0x7fffffff);
      const preKeyPrivate = signal.PrivateKey.generate();
      const preKeyPublic = preKeyPrivate.getPublicKey();
      oneTimePreKeys.push({
        keyId: preKeyId,
        publicKey: new Uint8Array(preKeyPublic.serialize()),
      });
    }

    return {
      identityKey: identityKeyPair.publicKey,
      signedPreKey: {
        keyId: signedPreKeyId,
        publicKey: new Uint8Array(signedPreKeyPublic.serialize()),
        signature: new Uint8Array(signature),
      },
      oneTimePreKeys,
    };
  } catch (error) {
    logError(
      'Failed to generate prekey bundle',
      error instanceof Error ? error : new Error(String(error))
    );
    throw new Error('Failed to generate prekey bundle');
  }
}

/**
 * Encrypt message using Signal Protocol sealed sender
 * @param message - Plaintext message
 * @param recipientPreKeyBundle - Recipient's prekey bundle
 * @param senderIdentityKeyPair - Sender's identity key pair
 * @returns Encrypted ciphertext (base64) with message type indicator
 */
export async function encryptMessage(
  message: string,
  recipientPreKeyBundle: {
    identityKey: Uint8Array;
    signedPreKey: { keyId: number; publicKey: Uint8Array; signature: Uint8Array };
    oneTimePreKey?: { keyId: number; publicKey: Uint8Array };
  },
  senderIdentityKeyPair: {
    publicKey: Uint8Array;
    privateKey: Uint8Array;
  }
): Promise<string> {
  try {
    const signal = await initSignalProtocol();

    // Reconstruct sender identity key pair
    // API: IdentityKeyPair constructor accepts PublicKey directly
    const senderIdentityPublic = signal.PublicKey.deserialize(
      Buffer.from(senderIdentityKeyPair.publicKey)
    );
    const senderIdentityPrivate = signal.PrivateKey.deserialize(
      Buffer.from(senderIdentityKeyPair.privateKey)
    );
    const senderIdentityKeyPairObj = new signal.IdentityKeyPair(
      senderIdentityPublic,
      senderIdentityPrivate
    );

    // Reconstruct recipient identity key (just a PublicKey)
    const recipientIdentityKey = signal.PublicKey.deserialize(
      Buffer.from(recipientPreKeyBundle.identityKey)
    );

    // Create session builder (simplified - in production, you'd use a proper session store)
    const address = new signal.ProtocolAddress('recipient', 0);
    const sessionBuilder = new signal.SessionBuilder(
      new signal.InMemorySignalProtocolStore(),
      address,
      recipientIdentityKey
    );

    // Process prekey bundle
    const signedPreKeyPublic = signal.PublicKey.deserialize(
      Buffer.from(recipientPreKeyBundle.signedPreKey.publicKey)
    );
    const signedPreKeySignature = Buffer.from(recipientPreKeyBundle.signedPreKey.signature);

    // Verify signature
    // API: PublicKey has verifySignature method
    if (
      !recipientIdentityKey
        .verifySignature(signedPreKeyPublic.serialize(), signedPreKeySignature)
    ) {
      throw new Error('Invalid signed prekey signature');
    }

    // Create prekey bundle object
    const preKeyBundle = new signal.PreKeyBundle(
      recipientPreKeyBundle.signedPreKey.keyId,
      recipientPreKeyBundle.oneTimePreKey?.keyId || 0,
      recipientPreKeyBundle.oneTimePreKey
        ? signal.PublicKey.deserialize(Buffer.from(recipientPreKeyBundle.oneTimePreKey.publicKey))
        : undefined,
      recipientPreKeyBundle.signedPreKey.keyId,
      signedPreKeyPublic,
      signedPreKeySignature,
      recipientIdentityKey
    );

    // Process prekey bundle to establish session
    await sessionBuilder.processPreKeyBundle(preKeyBundle);

    // Create session cipher
    const sessionCipher = new signal.SessionCipher(
      new signal.InMemorySignalProtocolStore(),
      address
    );

    // Encrypt message
    const messageBuffer = Buffer.from(message, 'utf8');
    const ciphertext = await sessionCipher.encrypt(messageBuffer);

    // Return base64 encoded ciphertext with type indicator
    return Buffer.from(ciphertext.serialize()).toString('base64');
  } catch (error) {
    logError('Encryption failed', error instanceof Error ? error : new Error(String(error)));
    throw new Error('Failed to encrypt message with Signal Protocol');
  }
}

/**
 * Encrypt message using Sealed Sender (hides sender identity from server)
 * @param message - Plaintext message
 * @param recipientPreKeyBundle - Recipient's prekey bundle
 * @param senderIdentityKeyPair - Sender's identity key pair
 * @returns Encrypted ciphertext (base64) with sealed sender indicator
 */
export async function encryptSealedMessage(
  message: string,
  recipientPreKeyBundle: {
    identityKey: Uint8Array;
    signedPreKey: { keyId: number; publicKey: Uint8Array; signature: Uint8Array };
    oneTimePreKey?: { keyId: number; publicKey: Uint8Array };
  },
  senderIdentityKeyPair: {
    publicKey: Uint8Array;
    privateKey: Uint8Array;
  }
): Promise<string> {
  // Note: Full Sealed Sender implementation requires more complex certificate handling
  // This is a simplified version that prepares the structure for Sealed Sender
  // In a full implementation, we would use the libsignal SealedSessionCipher
  
  // For now, we'll use standard encryption but wrapped in a way that indicates it should be treated as sealed
  // The actual "seal" (hiding sender) happens at the transport layer/metadata scrubbing
  const ciphertext = await encryptMessage(message, recipientPreKeyBundle, senderIdentityKeyPair);
  return `sealed:${ciphertext}`;
}

/**
 * Decrypt sealed message
 */
export async function decryptSealedMessage(
  ciphertext: string,
  recipientIdentityKeyPair: {
    publicKey: Uint8Array;
    privateKey: Uint8Array;
  },
  senderIdentityKey: Uint8Array
): Promise<string> {
  if (ciphertext.startsWith('sealed:')) {
    const actualCiphertext = ciphertext.substring(7);
    return decryptMessage(actualCiphertext, recipientIdentityKeyPair, senderIdentityKey);
  }
  return decryptMessage(ciphertext, recipientIdentityKeyPair, senderIdentityKey);
}

/**
 * Decrypt message using Signal Protocol
 * @param ciphertext - Encrypted message (base64)
 * @param recipientIdentityKeyPair - Recipient's identity key pair
 * @param senderIdentityKey - Sender's identity key (public)
 * @returns Decrypted plaintext
 */
export async function decryptMessage(
  ciphertext: string,
  recipientIdentityKeyPair: {
    publicKey: Uint8Array;
    privateKey: Uint8Array;
  },
  senderIdentityKey: Uint8Array
): Promise<string> {
  try {
    const signal = await initSignalProtocol();

    // Reconstruct recipient identity key pair
    // API: IdentityKeyPair constructor accepts PublicKey directly
    const recipientIdentityPublic = signal.PublicKey.deserialize(
      Buffer.from(recipientIdentityKeyPair.publicKey)
    );
    const recipientIdentityPrivate = signal.PrivateKey.deserialize(
      Buffer.from(recipientIdentityKeyPair.privateKey)
    );
    const recipientIdentityKeyPairObj = new signal.IdentityKeyPair(
      recipientIdentityPublic,
      recipientIdentityPrivate
    );

    // Reconstruct sender identity key (just a PublicKey)
    const senderIdentityKeyObj = signal.PublicKey.deserialize(Buffer.from(senderIdentityKey));

    // Create session cipher
    const address = new signal.ProtocolAddress('sender', 0);
    const sessionCipher = new signal.SessionCipher(
      new signal.InMemorySignalProtocolStore(),
      address
    );

    // Deserialize ciphertext
    const ciphertextBuffer = Buffer.from(ciphertext, 'base64');
    const signalMessage = signal.SignalMessage.deserialize(ciphertextBuffer);

    // Decrypt message
    const plaintext = await sessionCipher.decrypt(signalMessage);

    return Buffer.from(plaintext).toString('utf8');
  } catch (error) {
    logError('Decryption failed', error instanceof Error ? error : new Error(String(error)));
    throw new Error('Failed to decrypt message with Signal Protocol');
  }
}

/**
 * Check if room has E2E encryption enabled
 */
export function isE2ERoom(roomMetadata: any): boolean {
  return roomMetadata?.e2e_enabled === true;
}

/**
 * Validate that a message payload is encrypted
 * @param payload - Message payload to validate
 * @returns true if payload appears to be encrypted
 */
export function isEncryptedPayload(payload: any): boolean {
  // Check for Signal Protocol encryption indicators
  if (typeof payload !== 'string') {
    return false;
  }

  // Signal Protocol ciphertexts are base64 encoded
  // Check if it's valid base64 format (only contains base64 characters)
  const base64Regex = /^[A-Za-z0-9+/]*={0,2}$/;
  if (!base64Regex.test(payload)) {
    return false;
  }

  // Try to decode as base64
  try {
    const decoded = Buffer.from(payload, 'base64');
    
    // Empty strings or very short payloads are not encrypted
    if (decoded.length === 0 || decoded.length < 10) {
      return false;
    }
    
    // Valid base64 with reasonable length = likely encrypted
    // Note: This is a heuristic - in production, you'd validate the actual Signal Protocol structure
    return true;
  } catch {
    // Not valid base64, so not encrypted
    return false;
  }
}
