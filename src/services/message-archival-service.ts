/**
 * Message Archival Service
 * Implements hot/cold storage strategy for message retention
 *
 * Features:
 * - Archive messages older than 90 days to cold storage
 * - Encrypted archive format
 * - Archive retrieval API
 * - Archive integrity verification
 */

import { supabase } from '../config/database-config.js';
import { logError, logInfo, logWarning } from '../shared/logger-shared.js';
import {
  validateServiceData,
  validateBeforeDB,
  validateAfterDB,
} from '../middleware/validation/incremental-validation-middleware.js';
import { encryptField, decryptField } from './encryption-service.js';
import { z } from 'zod/v3';
import crypto from 'crypto';

// Configuration
const ARCHIVE_AGE_DAYS = parseInt(process.env.MESSAGE_ARCHIVE_AGE_DAYS || '90', 10);
const ARCHIVE_BATCH_SIZE = 1000; // Archive in batches

// Validation schemas
const archiveEligibilitySchema = z.object({
  messageId: z.string().uuid(),
  createdAt: z.string().datetime(),
  ageDays: z.number().positive(),
});

const archiveRecordSchema = z.object({
  message_id: z.string().uuid(),
  room_id: z.string().uuid(),
  archived_at: z.string().datetime(),
  archive_format: z.string(),
  archive_checksum: z.string(),
  cold_storage_uri: z.string().optional(),
});

/**
 * Check if message is eligible for archival
 */
export async function isMessageEligibleForArchive(
  messageId: string
): Promise<{ eligible: boolean; ageDays: number; reason?: string }> {
  try {
    // VALIDATION CHECKPOINT: Validate message ID format
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(messageId)) {
      return { eligible: false, ageDays: 0, reason: 'Invalid message ID format' };
    }

    const { data: message, error } = await supabase
      .from('messages')
      .select('id, created_at')
      .eq('id', messageId)
      .single();

    if (error || !message) {
      return { eligible: false, ageDays: 0, reason: 'Message not found' };
    }

    // VALIDATION CHECKPOINT: Validate message structure
    if (!message.created_at) {
      return { eligible: false, ageDays: 0, reason: 'Message missing created_at' };
    }

    const createdAt = new Date(message.created_at);
    const now = new Date();
    const ageMs = now.getTime() - createdAt.getTime();
    const ageDays = ageMs / (1000 * 60 * 60 * 24);

    // VALIDATION CHECKPOINT: Validate age calculation
    const eligibility = validateServiceData(
      { messageId, createdAt: message.created_at, ageDays },
      archiveEligibilitySchema,
      'isMessageEligibleForArchive'
    );

    const eligible = ageDays >= ARCHIVE_AGE_DAYS;

    return {
      eligible,
      ageDays: Math.floor(ageDays),
      reason: eligible
        ? undefined
        : `Message is only ${Math.floor(ageDays)} days old (requires ${ARCHIVE_AGE_DAYS} days)`,
    };
  } catch (error: any) {
    logError('Failed to check archive eligibility', error);
    return { eligible: false, ageDays: 0, reason: 'Check failed' };
  }
}

/**
 * Create archive format for message (encrypted JSON)
 */
async function createArchiveFormat(
  message: any
): Promise<{ format: string; data: string; checksum: string }> {
  try {
    // VALIDATION CHECKPOINT: Validate message structure before archiving
    if (!message || !message.id || !message.content) {
      throw new Error('Invalid message structure for archiving');
    }

    // Create archive record (minimal metadata)
    const archiveRecord = {
      id: message.id,
      room_id: message.room_id,
      sender_id: message.sender_id,
      content: message.content,
      created_at: message.created_at,
      archived_at: new Date().toISOString(),
    };

    // Serialize to JSON
    const jsonData = JSON.stringify(archiveRecord);

    // Encrypt archive data
    const encryptedData = await encryptField(jsonData);

    // Calculate checksum for integrity verification
    const checksum = crypto.createHash('sha256').update(encryptedData).digest('hex');

    // VALIDATION CHECKPOINT: Validate archive format
    if (!encryptedData || encryptedData.length === 0) {
      throw new Error('Archive encryption failed');
    }

    if (!checksum || checksum.length !== 64) {
      throw new Error('Archive checksum calculation failed');
    }

    return {
      format: 'encrypted_json_v1',
      data: encryptedData,
      checksum,
    };
  } catch (error: any) {
    logError('Failed to create archive format', error);
    throw error;
  }
}

/**
 * Archive a single message to cold storage
 */
export async function archiveMessage(
  messageId: string
): Promise<{ success: boolean; archiveId?: string; error?: string }> {
  try {
    // VALIDATION CHECKPOINT: Validate archive eligibility
    const eligibility = await isMessageEligibleForArchive(messageId);
    if (!eligibility.eligible) {
      return { success: false, error: eligibility.reason };
    }

    // Fetch full message data
    const { data: message, error: fetchError } = await supabase
      .from('messages')
      .select('*')
      .eq('id', messageId)
      .single();

    if (fetchError || !message) {
      return { success: false, error: 'Message not found' };
    }

    // Create archive format
    const archive = await createArchiveFormat(message);

    // Store archive (in production, this would go to S3/cloud storage)
    // For now, store in database archive table
    const archiveRecord = {
      message_id: messageId,
      room_id: message.room_id,
      archived_at: new Date().toISOString(),
      archive_format: archive.format,
      archive_checksum: archive.checksum,
      archive_data: archive.data, // In production, store URI to S3 instead
    };

    // VALIDATION CHECKPOINT: Validate archive record before DB insert
    const validatedArchive = validateBeforeDB(
      archiveRecord,
      archiveRecordSchema.extend({
        archive_data: z.string(),
      }),
      'archiveMessage'
    );

    // Insert archive record
    const { data: inserted, error: insertError } = await supabase
      .from('message_archives')
      .insert(validatedArchive)
      .select('id')
      .single();

    if (insertError) {
      // Check if archive table exists, if not, log warning
      if (insertError.code === '42P01') {
        logWarning('message_archives table does not exist - skipping archival', { messageId });
        return { success: false, error: 'Archive table not configured' };
      }
      throw insertError;
    }

    // VALIDATION CHECKPOINT: Validate archive inserted successfully
    if (!inserted || !inserted.id) {
      return { success: false, error: 'Archive insertion failed' };
    }

    // Mark original message as archived (soft delete or flag)
    await supabase.from('messages').update({ is_archived: true }).eq('id', messageId);

    logInfo(`Message archived: ${messageId} -> archive ${inserted.id}`);

    return { success: true, archiveId: inserted.id };
  } catch (error: any) {
    logError('Failed to archive message', error);
    return { success: false, error: error.message || 'Archive failed' };
  }
}

/**
 * Retrieve archived message
 */
export async function retrieveArchivedMessage(messageId: string): Promise<any | null> {
  try {
    // VALIDATION CHECKPOINT: Validate message ID format
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(messageId)) {
      throw new Error('Invalid message ID format');
    }

    // Fetch archive record
    const { data: archive, error } = await supabase
      .from('message_archives')
      .select('*')
      .eq('message_id', messageId)
      .single();

    if (error || !archive) {
      return null;
    }

    // VALIDATION CHECKPOINT: Validate archive structure
    if (!archive.archive_data || !archive.archive_checksum) {
      throw new Error('Invalid archive structure');
    }

    // Verify archive integrity
    const calculatedChecksum = crypto
      .createHash('sha256')
      .update(archive.archive_data)
      .digest('hex');

    // VALIDATION CHECKPOINT: Validate archive checksum
    if (calculatedChecksum !== archive.archive_checksum) {
      logError(
        'Archive integrity check failed',
        new Error(`Expected ${archive.archive_checksum}, got ${calculatedChecksum}`)
      );
      throw new Error('Archive integrity verification failed');
    }

    // Decrypt archive data
    const decryptedData = await decryptField(archive.archive_data);

    // VALIDATION CHECKPOINT: Validate decryption success
    if (!decryptedData) {
      throw new Error('Archive decryption failed');
    }

    // Parse JSON
    const messageData = JSON.parse(decryptedData);

    // VALIDATION CHECKPOINT: Validate retrieved message structure
    if (!messageData.id || !messageData.content) {
      throw new Error('Invalid message data in archive');
    }

    return messageData;
  } catch (error: any) {
    logError('Failed to retrieve archived message', error);
    return null;
  }
}

/**
 * Archive messages in batch (scheduled job)
 */
export async function archiveMessagesBatch(): Promise<{ archived: number; failed: number }> {
  try {
    const archiveThreshold = new Date();
    archiveThreshold.setDate(archiveThreshold.getDate() - ARCHIVE_AGE_DAYS);

    // VALIDATION CHECKPOINT: Validate archive threshold calculation
    if (archiveThreshold > new Date()) {
      logWarning('Archive threshold is in the future', {
        threshold: archiveThreshold.toISOString(),
      });
    }

    // Find messages eligible for archival
    const { data: messages, error } = await supabase
      .from('messages')
      .select('id, created_at, room_id')
      .lt('created_at', archiveThreshold.toISOString())
      .eq('is_archived', false)
      .limit(ARCHIVE_BATCH_SIZE);

    if (error) {
      throw error;
    }

    // VALIDATION CHECKPOINT: Validate batch query result
    if (!Array.isArray(messages)) {
      throw new Error('Batch query returned non-array result');
    }

    let archived = 0;
    let failed = 0;

    // Archive each message
    for (const message of messages) {
      const result = await archiveMessage(message.id);
      if (result.success) {
        archived++;
      } else {
        failed++;
        logWarning(`Failed to archive message ${message.id}`, { error: result.error });
      }
    }

    // VALIDATION CHECKPOINT: Validate batch archival completed
    logInfo(`Batch archival completed: ${archived} archived, ${failed} failed`);

    return { archived, failed };
  } catch (error: any) {
    logError('Batch archival failed', error);
    return { archived: 0, failed: 0 };
  }
}
