/**
 * Search Service
 * Full-text search across messages, rooms, and users
 * Uses PostgreSQL GIN indexes and RLS-safe RPC functions
 */

import { supabase } from '../config/db.js';
import { getRedisClient } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';

const redis = getRedisClient();

// Request deduplication map - prevents duplicate concurrent searches
const pendingSearches = new Map<string, Promise<SearchResult[]>>();
const MAX_PENDING_SEARCHES = 100; // Limit to prevent memory issues

export interface SearchResult {
  id: string;
  type: 'message' | 'room' | 'user';
  content: string;
  metadata: Record<string, any>;
  rank?: number;
}

export interface SearchOptions {
  query: string;
  type?: 'messages' | 'rooms' | 'users' | 'all';
  roomId?: string;
  userId?: string;
  limit?: number;
  offset?: number;
}

/**
 * Full-text search across messages, rooms, and users
 */
export async function fullTextSearch(options: SearchOptions): Promise<SearchResult[]> {
  try {
    const { query, type = 'all', roomId, userId, limit = 50, offset = 0 } = options;

    if (!query || query.trim().length === 0) {
      return [];
    }

    // Cache key for Redis (also used for deduplication)
    const cacheKey = `search:${type}:${query}:${roomId || 'all'}:${userId || 'all'}:${limit}:${offset}`;
    
    // Check cache
    const cached = await redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    // Check if same search is already in progress (request deduplication)
    if (pendingSearches.has(cacheKey)) {
      logInfo(`Deduplicating search request: ${cacheKey}`);
      return pendingSearches.get(cacheKey)!;
    }

    // Clean up old pending searches if map is too large
    if (pendingSearches.size >= MAX_PENDING_SEARCHES) {
      // Clear oldest entries (simple cleanup - in production, use LRU cache)
      const keysToDelete = Array.from(pendingSearches.keys()).slice(0, 20);
      keysToDelete.forEach(key => pendingSearches.delete(key));
      logInfo(`Cleaned up ${keysToDelete.length} pending searches`);
    }

    const results: SearchResult[] = [];

    // Parallelize search queries for better performance
    // Use Promise.allSettled to handle partial failures gracefully
    const searchPromises: Promise<any>[] = [];

    // Search messages
    if (type === 'all' || type === 'messages') {
      searchPromises.push(
        supabase.rpc('search_messages_fulltext', {
          search_query: query,
          filter_room_id: roomId || null,
          filter_user_id: userId || null,
          result_limit: limit
        }).then(result => ({ type: 'messages', ...result }))
      );
    }

    // Search rooms
    if (type === 'all' || type === 'rooms') {
      searchPromises.push(
        supabase.rpc('search_rooms_fulltext', {
          search_query: query,
          result_limit: limit
        }).then(result => ({ type: 'rooms', ...result }))
      );
    }

    // Search users (if users table has searchable fields)
    if (type === 'all' || type === 'users') {
      searchPromises.push(
        supabase
          .from('users')
          .select('id, username, display_name')
          .or(`username.ilike.%${query}%,display_name.ilike.%${query}%`)
          .limit(limit)
          .then(result => ({ type: 'users', ...result }))
      );
    }

    // Execute all searches in parallel
    const searchResults = await Promise.allSettled(searchPromises);

    // Process results from parallel searches
    for (const result of searchResults) {
      if (result.status === 'rejected') {
        logError('Search query failed', result.reason);
        continue;
      }

      const { value } = result;
      const { type: resultType, data, error } = value;

      if (error) {
        logError(`${resultType} search failed`, error);
        continue;
      }

      if (!data) {
        continue;
      }

      // Process messages
      if (resultType === 'messages') {
        results.push(...data.map((m: any) => ({
          id: m.id,
          type: 'message' as const,
          content: m.content_preview || '',
          metadata: {
            room_id: m.room_id,
            sender_id: m.sender_id,
            created_at: m.created_at
          },
          rank: m.rank
        })));
      }

      // Process rooms
      if (resultType === 'rooms') {
        results.push(...data.map((r: any) => ({
          id: r.id,
          type: 'room' as const,
          content: r.title || r.slug || '',
          metadata: {
            slug: r.slug,
            created_at: r.created_at
          },
          rank: r.rank
        })));
      }

      // Process users
      if (resultType === 'users') {
        results.push(...data.map((u: any) => ({
          id: u.id,
          type: 'user' as const,
          content: u.display_name || u.username || '',
          metadata: {
            username: u.username
          }
        })));
      }
    }

    // Sort by rank if available, then by relevance
    results.sort((a, b) => {
      if (a.rank && b.rank) {
        return b.rank - a.rank;
      }
      return 0;
    });

    // Cache results for 5 minutes
    await redis.setex(cacheKey, 300, JSON.stringify(results));

    logInfo(`Search completed: ${results.length} results for query "${query}"`);
    return results;
  } catch (error: any) {
    logError('Full-text search failed', error);
    return [];
  }
}

/**
 * Search messages in a specific room
 */
export async function searchRoomMessages(
  roomId: string,
  query: string,
  limit: number = 50
): Promise<SearchResult[]> {
  return fullTextSearch({
    query,
    type: 'messages',
    roomId,
    limit
  });
}

/**
 * Search public rooms
 */
export async function searchRooms(
  query: string,
  limit: number = 20
): Promise<SearchResult[]> {
  return fullTextSearch({
    query,
    type: 'rooms',
    limit
  });
}

