/**
 * Room Expiry Cron Job
 * Expires temporary Pro-tier rooms that have passed their expiration date
 * Run via Supabase Edge Functions, cron-job.org, or scheduled task
 */

import { supabase } from '../config/db.js';
import { logInfo, logError } from '../shared/logger.js';

/**
 * Expire temporary Pro-tier rooms
 * Deletes rooms where expires_at < now() and room_tier = 'pro'
 */
export default async function expireRooms(): Promise<void> {
  try {
    const now = new Date().toISOString();
    
    // Find expired Pro rooms
    const { data: expiredRooms, error: fetchError } = await supabase
      .from('rooms')
      .select('id, title, expires_at')
      .lt('expires_at', now)
      .eq('room_tier', 'pro');

    if (fetchError) {
      logError('Failed to fetch expired rooms', fetchError);
      throw fetchError;
    }

    if (!expiredRooms || expiredRooms.length === 0) {
      logInfo('No expired rooms to clean up');
      return;
    }

    // Delete expired rooms
    const roomIds = expiredRooms.map(r => r.id);
    const { error: deleteError } = await supabase
      .from('rooms')
      .delete()
      .in('id', roomIds);

    if (deleteError) {
      logError('Failed to delete expired rooms', deleteError);
      throw deleteError;
    }

    logInfo(`Expired ${roomIds.length} temporary Pro rooms: ${roomIds.join(', ')}`);
  } catch (error: any) {
    logError('Room expiry job failed', error);
    throw error;
  }
}

// If run directly (e.g., via cron or scheduled task)
if (import.meta.url === `file://${process.argv[1]}`) {
  expireRooms()
    .then(() => {
      logInfo('Room expiry job completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      logError('Room expiry job failed', error);
      process.exit(1);
    });
}

