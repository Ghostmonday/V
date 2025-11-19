/**
 * Query Optimization Service
 * Cursor-based pagination and query optimization utilities
 */

import { supabase } from '../config/database-config.js';
import { logError } from '../shared/logger-shared.js';

export interface PaginationOptions {
  limit: number;
  cursor?: string; // ISO timestamp or UUID
  direction?: 'forward' | 'backward';
}

export interface PaginatedResult<T> {
  data: T[];
  nextCursor?: string;
  prevCursor?: string;
  hasMore: boolean;
}

/**
 * Get messages with cursor-based pagination (optimized)
 * Uses cursor instead of OFFSET for better performance
 */
export async function getMessagesPaginated(
  roomId: string,
  options: PaginationOptions
): Promise<PaginatedResult<any>> {
  try {
    // VALIDATION CHECKPOINT: Validate room ID format
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(roomId)) {
      throw new Error('Invalid room ID format');
    }

    // VALIDATION CHECKPOINT: Validate limit value (1-100)
    const limit = Math.max(1, Math.min(100, options.limit || 50));
    const { cursor, direction = 'backward' } = options;

    // VALIDATION CHECKPOINT: Validate cursor format if provided
    if (cursor && !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(cursor)) {
      throw new Error('Invalid cursor format. Must be ISO timestamp.');
    }

    // VALIDATION CHECKPOINT: Validate pagination direction
    if (direction !== 'forward' && direction !== 'backward') {
      throw new Error('Invalid pagination direction. Must be "forward" or "backward".');
    }

    let query = supabase
      .from('messages')
      .select('*')
      .eq('room_id', roomId)
      .order('created_at', { ascending: direction === 'forward' });

    // Cursor-based pagination (more efficient than OFFSET)
    if (cursor) {
      if (direction === 'backward') {
        // Get messages before cursor (older messages)
        query = query.lt('created_at', cursor);
      } else {
        // Get messages after cursor (newer messages)
        query = query.gt('created_at', cursor);
      }
    }

    // Limit + 1 to check if there are more results
    const { data, error } = await query.limit(limit + 1);

    if (error) {
      throw error;
    }

    const messages = data || [];

    // VALIDATION CHECKPOINT: Validate result set structure
    if (!Array.isArray(messages)) {
      throw new Error('Query returned non-array result');
    }

    const hasMore = messages.length > limit;
    const resultMessages = hasMore ? messages.slice(0, limit) : messages;

    // Generate cursors
    const nextCursor =
      hasMore && resultMessages.length > 0
        ? resultMessages[resultMessages.length - 1].created_at
        : undefined;
    const prevCursor = resultMessages.length > 0 ? resultMessages[0].created_at : undefined;

    // VALIDATION CHECKPOINT: Validate cursor calculation
    if (nextCursor && typeof nextCursor !== 'string') {
      logError('Invalid next cursor type', new Error(`Expected string, got ${typeof nextCursor}`));
    }

    return {
      data: resultMessages,
      nextCursor,
      prevCursor,
      hasMore,
    };
  } catch (error: any) {
    logError('Failed to get paginated messages', error);
    return {
      data: [],
      hasMore: false,
    };
  }
}

/**
 * Optimize conversation history query with proper indexing
 */
export async function getConversationHistory(
  roomId: string,
  limit: number = 50,
  before?: string
): Promise<any[]> {
  try {
    let query = supabase
      .from('messages')
      .select('*, sender:users(handle, display_name)')
      .eq('room_id', roomId)
      .order('created_at', { ascending: false })
      .limit(limit);

    // Use cursor if provided (more efficient than OFFSET)
    if (before) {
      query = query.lt('created_at', before);
    }

    const { data, error } = await query;

    if (error) {
      throw error;
    }

    return data || [];
  } catch (error: any) {
    logError('Failed to get conversation history', error);
    return [];
  }
}
