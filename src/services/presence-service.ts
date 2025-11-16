import { getRedisClient } from '../config/db.ts';
import { supabase } from '../config/db.ts';
import { logAudit, logError } from '../shared/logger.js';

const redis = getRedisClient();

// User presence (online/offline status)
export async function getPresence(userId: string) {
  const status = await redis.get(`presence:${userId}`);
  return { status: status || 'offline' };
}

export async function updatePresence(userId: string, status: string) {
  await redis.set(`presence:${userId}`, status, 'EX', 3600); // expire in 1 hour
  await redis.publish('presence_updates', JSON.stringify({ userId, status, ts: Date.now() }));
}

export async function updateRoomPresence(roomId: string, userId: string, status: string): Promise<void> {
  // Set Redis key with TTL to prevent orphaned keys (1 hour expiration)
  await redis.hset(`presence:${roomId}`, userId, status);
  await redis.expire(`presence:${roomId}`, 3600); // 1 hour TTL
  
  // Also set individual user presence key with TTL
  await redis.set(`presence:${userId}`, status, 'EX', 3600); // 1 hour TTL
  
  await supabase.from('presence_logs').insert({ user_id: userId, room_id: roomId, status });
  await logAudit('presence_update', userId, { room_id: roomId, status });
}

export async function getRoomPresence(roomId: string): Promise<Record<string, string>> {
  return await redis.hgetall(`presence:${roomId}`);
}

export async function getOnlineStatus(userId: string): Promise<string> {
  // Check individual user presence key first (more efficient)
  const userStatus = await redis.get(`presence:${userId}`);
  if (userStatus) return userStatus;
  
  // Fallback: check room presence keys (less efficient, but comprehensive)
  const keys = await redis.keys('presence:*');
  for (const key of keys) {
    // Skip individual user keys (already checked above)
    if (key === `presence:${userId}`) continue;
    
    const status = await redis.hget(key, userId);
    if (status) return status;
  }
  return 'offline';
}

/**
 * Clean up orphaned Redis presence keys
 * Removes keys that have expired TTL but weren't cleaned up automatically
 * Should be run periodically (e.g., daily cron job)
 */
export async function cleanupOrphanedPresenceKeys(): Promise<number> {
  let cleanedCount = 0;
  
  try {
    // Get all presence keys
    const keys = await redis.keys('presence:*');
    
    for (const key of keys) {
      // Check if key has TTL (if TTL is -1, it's a permanent key - skip)
      const ttl = await redis.ttl(key);
      
      // If key has no TTL or is expired, remove it
      if (ttl === -1 || ttl === -2) {
        await redis.del(key);
        cleanedCount++;
      }
    }
    
    return cleanedCount;
  } catch (error) {
    logError('Failed to cleanup orphaned presence keys', error instanceof Error ? error : new Error(String(error)));
    return cleanedCount;
  }
}

/**
 * List public rooms ordered by active users
 * Phase 3.4: Cached for 1 minute (presence changes frequently)
 */
export async function listRooms(): Promise<any[]> {
  const { warmCache } = await import('./cache-service.js');
  
  const cacheKey = 'rooms:public:active_users';
  return await warmCache(
    cacheKey,
    async () => {
      const { data } = await supabase
        .from('rooms')
        .select('*')
        .eq('is_public', true)
        .order('active_users', { ascending: false });
      return data || [];
    },
    60 // 1 minute TTL (presence changes frequently)
  );
}

export async function getActivityFeed(userId: string): Promise<any[]> {
  const { data } = await supabase
    .from('messages')
    .select('*, rooms(*)')
    .eq('sender_id', userId)
    .order('created_at', { ascending: false })
    .limit(50);
  return data || [];
}
