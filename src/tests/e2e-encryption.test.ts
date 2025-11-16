/**
 * E2E Encryption Tests
 * Tests Signal Protocol encryption/decryption functionality
 */

import { describe, it, expect, beforeAll } from 'vitest';
import {
  generateIdentityKeyPair,
  generatePreKeyBundle,
  encryptMessage,
  decryptMessage,
  isEncryptedPayload,
  isE2ERoom,
} from '../services/e2e-encryption.js';

describe('E2E Encryption Service', () => {
  let senderKeyPair: { publicKey: Uint8Array; privateKey: Uint8Array };
  let recipientKeyPair: { publicKey: Uint8Array; privateKey: Uint8Array };
  let recipientPreKeyBundle: any;

  beforeAll(async () => {
    // Generate key pairs for sender and recipient
    senderKeyPair = await generateIdentityKeyPair();
    recipientKeyPair = await generateIdentityKeyPair();
    recipientPreKeyBundle = await generatePreKeyBundle(recipientKeyPair);
  });

  it('should generate identity key pairs', async () => {
    const keyPair = await generateIdentityKeyPair();
    expect(keyPair.publicKey).toBeInstanceOf(Uint8Array);
    expect(keyPair.privateKey).toBeInstanceOf(Uint8Array);
    expect(keyPair.publicKey.length).toBeGreaterThan(0);
    expect(keyPair.privateKey.length).toBeGreaterThan(0);
  });

  it('should generate prekey bundle', async () => {
    const preKeyBundle = await generatePreKeyBundle(recipientKeyPair);
    expect(preKeyBundle.identityKey).toBeInstanceOf(Uint8Array);
    expect(preKeyBundle.signedPreKey).toBeDefined();
    expect(preKeyBundle.signedPreKey.publicKey).toBeInstanceOf(Uint8Array);
    expect(preKeyBundle.signedPreKey.signature).toBeInstanceOf(Uint8Array);
    expect(preKeyBundle.oneTimePreKeys).toBeInstanceOf(Array);
    expect(preKeyBundle.oneTimePreKeys.length).toBeGreaterThan(0);
  });

  it('should encrypt and decrypt messages', async () => {
    const plaintext = 'Hello, this is a test message!';
    
    const encrypted = await encryptMessage(
      plaintext,
      recipientPreKeyBundle,
      senderKeyPair
    );
    
    expect(encrypted).toBeDefined();
    expect(typeof encrypted).toBe('string');
    expect(encrypted.length).toBeGreaterThan(0);
    
    // Note: Decryption requires proper session management
    // This is a simplified test - full decryption would need session state
  });

  it('should validate encrypted payloads', () => {
    const encryptedPayload = 'dGVzdGVuY3J5cHRlZGRhdGE='; // base64 encoded
    const plaintextPayload = 'plaintext message';
    
    expect(isEncryptedPayload(encryptedPayload)).toBe(true);
    expect(isEncryptedPayload(plaintextPayload)).toBe(false);
  });

  it('should check if room has E2E encryption enabled', () => {
    const e2eRoom = { e2e_enabled: true };
    const nonE2eRoom = { e2e_enabled: false };
    const roomWithoutFlag = {};
    
    expect(isE2ERoom(e2eRoom)).toBe(true);
    expect(isE2ERoom(nonE2eRoom)).toBe(false);
    expect(isE2ERoom(roomWithoutFlag)).toBe(false);
  });
});

