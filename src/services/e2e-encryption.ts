/**
 * E2E Encryption Service
 * Uses libsodium.js for sealed boxes (encryption)
 */

import sodium from 'libsodium-wrappers';
import { logError } from '../shared/logger.js';

let sodiumReady = false;

/**
 * Initialize sodium library
 */
async function initSodium(): Promise<void> {
  if (sodiumReady) return;
  
  await sodium.ready;
  sodiumReady = true;
}

/**
 * Generate key pair for E2E encryption
 */
export async function generateKeyPair(): Promise<{ publicKey: Uint8Array; privateKey: Uint8Array }> {
  await initSodium();
  
  const keyPair = sodium.crypto_box_keypair();
  return {
    publicKey: keyPair.publicKey,
    privateKey: keyPair.privateKey,
  };
}

/**
 * Encrypt message using sealed box (recipient's public key)
 * @param message - Plaintext message
 * @param recipientPublicKey - Recipient's public key (Uint8Array or base64 string)
 * @returns Encrypted ciphertext (base64)
 */
export async function encryptMessage(
  message: string,
  recipientPublicKey: Uint8Array | string
): Promise<string> {
  try {
    await initSodium();
    
    const publicKey = typeof recipientPublicKey === 'string'
      ? sodium.from_base64(recipientPublicKey)
      : recipientPublicKey;
    
    const messageBytes = sodium.from_string(message);
    const ciphertext = sodium.crypto_box_seal(messageBytes, publicKey);
    
    return sodium.to_base64(ciphertext);
  } catch (error) {
    logError('Encryption failed', error instanceof Error ? error : new Error(String(error)));
    throw new Error('Failed to encrypt message');
  }
}

/**
 * Decrypt message using sealed box (recipient's private key)
 * @param ciphertext - Encrypted message (base64)
 * @param recipientPrivateKey - Recipient's private key (Uint8Array or base64 string)
 * @param senderPublicKey - Sender's public key (Uint8Array or base64 string)
 * @returns Decrypted plaintext
 */
export async function decryptMessage(
  ciphertext: string,
  recipientPrivateKey: Uint8Array | string,
  senderPublicKey: Uint8Array | string
): Promise<string> {
  try {
    await initSodium();
    
    const privateKey = typeof recipientPrivateKey === 'string'
      ? sodium.from_base64(recipientPrivateKey)
      : recipientPrivateKey;
    
    const publicKey = typeof senderPublicKey === 'string'
      ? sodium.from_base64(senderPublicKey)
      : senderPublicKey;
    
    const ciphertextBytes = sodium.from_base64(ciphertext);
    const messageBytes = sodium.crypto_box_seal_open(ciphertextBytes, publicKey, privateKey);
    
    return sodium.to_string(messageBytes);
  } catch (error) {
    logError('Decryption failed', error instanceof Error ? error : new Error(String(error)));
    throw new Error('Failed to decrypt message');
  }
}

/**
 * Check if room has E2E encryption enabled
 */
export function isE2ERoom(roomMetadata: any): boolean {
  return roomMetadata?.e2e_enabled === true;
}

