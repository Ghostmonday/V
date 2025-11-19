/**
 * PII Encryption Integration Service
 * Provides transparent encryption/decryption hooks for PII fields
 */

import { supabase } from '../config/database-config.js';
import { encryptField, decryptField } from './encryption-service.js';
import { logError, logInfo } from '../shared/logger-shared.js';

/**
 * Fields that should be encrypted at rest
 */
const PII_FIELDS = {
  users: ['email'],
  refresh_tokens: ['ip_address'],
  consent_records: ['ip_address'],
  audit_log: ['ip_address'], // If stored
};

/**
 * Encrypt PII fields before database insert/update
 */
export async function encryptPIIBeforeSave(
  tableName: string,
  data: Record<string, any>
): Promise<Record<string, any>> {
  const fieldsToEncrypt = PII_FIELDS[tableName as keyof typeof PII_FIELDS] || [];

  if (fieldsToEncrypt.length === 0) {
    return data;
  }

  const encrypted = { ...data };

  for (const field of fieldsToEncrypt) {
    if (encrypted[field] && typeof encrypted[field] === 'string' && encrypted[field].length > 0) {
      try {
        // Check if already encrypted (has colons in format)
        if (!encrypted[field].includes(':')) {
          encrypted[field] = await encryptField(encrypted[field]);
          logInfo(`Encrypted ${field} for table ${tableName}`);
        }
      } catch (error: any) {
        logError(`Failed to encrypt ${field} for table ${tableName}`, error);
        // Don't fail - log and continue (backward compatibility)
      }
    }
  }

  return encrypted;
}

/**
 * Decrypt PII fields after database read
 */
export async function decryptPIIAfterRead(
  tableName: string,
  data: Record<string, any> | Record<string, any>[]
): Promise<Record<string, any> | Record<string, any>[]> {
  const fieldsToDecrypt = PII_FIELDS[tableName as keyof typeof PII_FIELDS] || [];

  if (fieldsToDecrypt.length === 0) {
    return data;
  }

  // Handle array of records
  if (Array.isArray(data)) {
    return Promise.all(
      data.map((record) => decryptPIIAfterRead(tableName, record) as Promise<Record<string, any>>)
    );
  }

  const decrypted = { ...data };

  for (const field of fieldsToDecrypt) {
    if (decrypted[field] && typeof decrypted[field] === 'string' && decrypted[field].length > 0) {
      try {
        // Check if encrypted (has colons in format)
        if (decrypted[field].includes(':')) {
          decrypted[field] = await decryptField(decrypted[field]);
        }
      } catch (error: any) {
        logError(`Failed to decrypt ${field} for table ${tableName}`, error);
        // Return encrypted value if decryption fails
        decrypted[field] = '[encrypted]';
      }
    }
  }

  return decrypted;
}

/**
 * Migrate existing PII fields to encrypted format
 * Run this once to encrypt existing plaintext PII
 */
export async function migratePIIToEncrypted(): Promise<{ encrypted: number; errors: string[] }> {
  const errors: string[] = [];
  let encrypted = 0;

  try {
    // Migrate user emails
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, email')
      .not('email', 'is', null)
      .limit(1000); // Process in batches

    if (usersError) {
      errors.push(`Failed to fetch users: ${usersError.message}`);
    } else if (users) {
      for (const user of users) {
        if (user.email && !user.email.includes(':')) {
          // Not encrypted yet
          try {
            const encryptedEmail = await encryptField(user.email);
            const { error: updateError } = await supabase
              .from('users')
              .update({ email: encryptedEmail })
              .eq('id', user.id);

            if (updateError) {
              errors.push(`Failed to encrypt email for user ${user.id}: ${updateError.message}`);
            } else {
              encrypted++;
            }
          } catch (error: any) {
            errors.push(`Error encrypting email for user ${user.id}: ${error.message}`);
          }
        }
      }
    }

    // Migrate refresh token IP addresses
    const { data: tokens, error: tokensError } = await supabase
      .from('refresh_tokens')
      .select('id, ip_address')
      .not('ip_address', 'is', null)
      .limit(1000);

    if (tokensError) {
      errors.push(`Failed to fetch refresh tokens: ${tokensError.message}`);
    } else if (tokens) {
      for (const token of tokens) {
        if (token.ip_address && !token.ip_address.includes(':')) {
          try {
            const encryptedIP = await encryptField(token.ip_address);
            const { error: updateError } = await supabase
              .from('refresh_tokens')
              .update({ ip_address: encryptedIP })
              .eq('id', token.id);

            if (updateError) {
              errors.push(`Failed to encrypt IP for token ${token.id}: ${updateError.message}`);
            } else {
              encrypted++;
            }
          } catch (error: any) {
            errors.push(`Error encrypting IP for token ${token.id}: ${error.message}`);
          }
        }
      }
    }

    logInfo(`Migrated ${encrypted} PII fields to encrypted format`);
  } catch (error: any) {
    errors.push(`Migration error: ${error.message}`);
    logError('PII migration failed', error);
  }

  return { encrypted, errors };
}
