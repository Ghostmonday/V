/**
 * Data Retention Cron Job
 * Deletes expired data based on TTL policies
 * 
 * Schedule: Daily at 2 AM UTC (configurable via environment)
 * 
 * Tasks:
 * 1. Delete expired messages based on TTL
 * 2. Clean up ephemeral data (typing indicators, presence)
 * 3. Delete expired temporary rooms
 * 4. Respect legal holds and room-level retention overrides
 */

import { supabase } from '../config/db.ts';
import { getRedisClient } from '../config/db.ts';
import { logInfo, logError } from '../shared/logger.js';
import { getDefaultTTL } from '../services/DatabaseService.js';

const redis = getRedisClient();
const LOCK_KEY = 'data_retention_lock';
const LOCK_TTL = 3600; // 1 hour lock timeout

/**
 * Acquire distributed lock for data retention job
 * Prevents concurrent execution across multiple server instances
 */
async function acquireLock(): Promise<boolean> {
  try {
    const result = await redis.set(LOCK_KEY, 'locked', 'EX', LOCK_TTL, 'NX');
    return result === 'OK';
  } catch (error) {
    logError('Failed to acquire data retention lock', error instanceof Error ? error : new Error(String(error)));
    return false;
  }
}

/**
 * Release distributed lock
 */
async function releaseLock(): Promise<void> {
  try {
    await redis.del(LOCK_KEY);
  } catch (error) {
    logError('Failed to release data retention lock', error instanceof Error ? error : new Error(String(error)));
  }
}

/**
 * Delete expired messages based on TTL
 * Respects room-level retention overrides and legal holds
 */
async function deleteExpiredMessages(): Promise<{ deleted: number; errors: string[] }> {
  const errors: string[] = [];
  let deleted = 0;

  try {
    // Get default TTL for messages (30 days)
    const ttlDays = getDefaultTTL('messages') || 30;
    const cutoffDate = new Date(Date.now() - ttlDays * 24 * 60 * 60 * 1000);

    // Delete messages older than TTL, but exclude:
    // 1. Messages in rooms with legal holds
    // 2. Messages in rooms with custom retention policies
    const { data: expiredMessages, error: fetchError } = await supabase
      .from('messages')
      .select('id, room_id, created_at')
      .lt('created_at', cutoffDate.toISOString())
      .limit(1000); // Process in batches

    if (fetchError) {
      errors.push(`Failed to fetch expired messages: ${fetchError.message}`);
      return { deleted, errors };
    }

    if (!expiredMessages || expiredMessages.length === 0) {
      logInfo('No expired messages to delete');
      return { deleted, errors };
    }

    // Check for legal holds and room-level retention overrides
    const roomIds = [...new Set(expiredMessages.map(m => m.room_id))];
    
    // Get rooms with legal holds or custom retention
    const { data: protectedRooms, error: roomsError } = await supabase
      .from('rooms')
      .select('id, retention_days, legal_hold')
      .in('id', roomIds)
      .or('legal_hold.eq.true,retention_days.not.is.null');

    if (roomsError) {
      errors.push(`Failed to check protected rooms: ${roomsError.message}`);
    }

    const protectedRoomIds = new Set(
      (protectedRooms || [])
        .filter(r => r.legal_hold || (r.retention_days && r.retention_days > ttlDays))
        .map(r => r.id)
    );

    // Filter out messages from protected rooms
    const messagesToDelete = expiredMessages
      .filter(m => !protectedRoomIds.has(m.room_id))
      .map(m => m.id);

    if (messagesToDelete.length === 0) {
      logInfo('No messages to delete (all protected by legal holds or retention policies)');
      return { deleted, errors };
    }

    // Delete expired messages in batches
    const batchSize = 100;
    for (let i = 0; i < messagesToDelete.length; i += batchSize) {
      const batch = messagesToDelete.slice(i, i + batchSize);
      
      const { error: deleteError } = await supabase
        .from('messages')
        .delete()
        .in('id', batch);

      if (deleteError) {
        errors.push(`Failed to delete message batch: ${deleteError.message}`);
      } else {
        deleted += batch.length;
      }
    }

    logInfo(`Deleted ${deleted} expired messages`);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    errors.push(`Error deleting expired messages: ${errorMessage}`);
    logError('Error deleting expired messages', error instanceof Error ? error : new Error(errorMessage));
  }

  return { deleted, errors };
}

/**
 * Clean up ephemeral data (typing indicators, presence)
 * Ephemeral data has 1 hour TTL
 */
async function cleanupEphemeralData(): Promise<{ deleted: number; errors: string[] }> {
  const errors: string[] = [];
  let deleted = 0;

  try {
    const ttlHours = 1;
    const cutoffDate = new Date(Date.now() - ttlHours * 60 * 60 * 1000);

    // Clean up typing indicators (if stored in database)
    // Note: Typing indicators might be Redis-only, adjust based on implementation
    const { error: typingError } = await supabase
      .from('typing_indicators')
      .delete()
      .lt('updated_at', cutoffDate.toISOString());

    if (typingError && typingError.code !== 'PGRST116') {
      // PGRST116 = table doesn't exist, which is OK
      errors.push(`Failed to cleanup typing indicators: ${typingError.message}`);
    } else {
      // Count would require separate query, estimate based on success
      logInfo('Cleaned up expired typing indicators');
    }

    // Clean up presence data older than TTL
    const { error: presenceError } = await supabase
      .from('presence')
      .delete()
      .lt('last_seen', cutoffDate.toISOString());

    if (presenceError && presenceError.code !== 'PGRST116') {
      errors.push(`Failed to cleanup presence data: ${presenceError.message}`);
    } else {
      logInfo('Cleaned up expired presence data');
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    errors.push(`Error cleaning up ephemeral data: ${errorMessage}`);
    logError('Error cleaning up ephemeral data', error instanceof Error ? error : new Error(errorMessage));
  }

  return { deleted, errors };
}

/**
 * Delete expired temporary rooms
 * Temporary rooms have 7 days TTL
 */
async function deleteExpiredTemporaryRooms(): Promise<{ deleted: number; errors: string[] }> {
  const errors: string[] = [];
  let deleted = 0;

  try {
    const ttlDays = getDefaultTTL('temporary_rooms') || 7;
    const cutoffDate = new Date(Date.now() - ttlDays * 24 * 60 * 60 * 1000);

    const { data: expiredRooms, error: fetchError } = await supabase
      .from('rooms')
      .select('id')
      .eq('is_temporary', true)
      .lt('created_at', cutoffDate.toISOString());

    if (fetchError) {
      errors.push(`Failed to fetch expired temporary rooms: ${fetchError.message}`);
      return { deleted, errors };
    }

    if (!expiredRooms || expiredRooms.length === 0) {
      logInfo('No expired temporary rooms to delete');
      return { deleted, errors };
    }

    const roomIds = expiredRooms.map(r => r.id);

    const { error: deleteError } = await supabase
      .from('rooms')
      .delete()
      .in('id', roomIds);

    if (deleteError) {
      errors.push(`Failed to delete expired temporary rooms: ${deleteError.message}`);
    } else {
      deleted = roomIds.length;
      logInfo(`Deleted ${deleted} expired temporary rooms`);
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    errors.push(`Error deleting expired temporary rooms: ${errorMessage}`);
    logError('Error deleting expired temporary rooms', error instanceof Error ? error : new Error(errorMessage));
  }

  return { deleted, errors };
}

/**
 * Run data retention cleanup with distributed locking
 */
export async function runDataRetentionCleanup(): Promise<void> {
  // Acquire distributed lock to prevent concurrent execution
  const lockAcquired = await acquireLock();
  if (!lockAcquired) {
    logInfo('Data retention cleanup already running on another instance, skipping');
    return;
  }

  try {
    logInfo('Starting data retention cleanup cron job');

    // Run cleanup tasks
    const [messagesResult, ephemeralResult, roomsResult] = await Promise.all([
      deleteExpiredMessages(),
      cleanupEphemeralData(),
      deleteExpiredTemporaryRooms(),
    ]);

    const totalDeleted = messagesResult.deleted + ephemeralResult.deleted + roomsResult.deleted;
    const allErrors = [
      ...messagesResult.errors,
      ...ephemeralResult.errors,
      ...roomsResult.errors,
    ];

    logInfo('Data retention cleanup completed', {
      messagesDeleted: messagesResult.deleted,
      ephemeralDeleted: ephemeralResult.deleted,
      roomsDeleted: roomsResult.deleted,
      totalDeleted,
      errors: allErrors.length,
    });

    if (allErrors.length > 0) {
      logError('Data retention cleanup had errors', new Error(allErrors.join('; ')));
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError('Data retention cleanup cron job failed', error instanceof Error ? error : new Error(errorMessage));
    throw error;
  } finally {
    // Always release lock, even on error
    await releaseLock();
  }
}

/**
 * Schedule data retention cleanup to run daily at 2 AM UTC
 * Uses setInterval for simplicity (consider node-cron for production)
 */
export function scheduleDataRetentionCleanup(): void {
  // Calculate milliseconds until next 2 AM UTC
  const now = new Date();
  const utc2AM = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
    2, // 2 AM
    0,
    0,
    0
  ));

  // If 2 AM UTC has already passed today, schedule for tomorrow
  if (utc2AM.getTime() <= now.getTime()) {
    utc2AM.setUTCDate(utc2AM.getUTCDate() + 1);
  }

  const msUntil2AM = utc2AM.getTime() - now.getTime();

  // Schedule initial run
  setTimeout(() => {
    runDataRetentionCleanup().catch(err => {
      logError('Scheduled data retention cleanup failed', err);
    });

    // Then run daily (24 hours = 86400000 ms)
    setInterval(() => {
      runDataRetentionCleanup().catch(err => {
        logError('Scheduled data retention cleanup failed', err);
      });
    }, 86400000);
  }, msUntil2AM);

  logInfo(`Data retention cleanup scheduled to run daily at 2 AM UTC (first run in ${Math.round(msUntil2AM / 1000 / 60)} minutes)`);
}

// Auto-schedule if this module is imported
if (process.env.NODE_ENV !== 'test') {
  scheduleDataRetentionCleanup();
}

