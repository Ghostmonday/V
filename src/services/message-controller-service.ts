/**
 * Messages Controller
 * Handles reactions, threads, and message management
 */

import { Request, Response } from 'express';
import { supabase } from '../config/database-config.js';
import { redisPublisher } from '../config/redis-pubsub-config.js';
import { recordTelemetryEvent } from './telemetry-service.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { findMany, PaginatedResult } from '../shared/supabase-helpers-shared.js';
import type {
  MessageReaction,
  ReactionUpdate,
  CreateThreadRequest,
  Thread,
} from '../types/message.types.js';

export class MessagesController {
  /**
   * SIN-202: Add or toggle reaction
   */
  async addReaction(req: Request, res: Response): Promise<void> {
    try {
      const { message_id } = req.params;
      const { emoji, user_id } = req.body;

      if (!message_id || typeof message_id !== 'string') {
        res.status(400).json({ error: 'Invalid message_id' });
        return;
      }

      if (!emoji || typeof emoji !== 'string') {
        res.status(400).json({ error: 'Invalid emoji' });
        return;
      }

      if (!user_id || typeof user_id !== 'string') {
        res.status(400).json({ error: 'Invalid user_id' });
        return;
      }

      // Get current message
      const { data: message, error: messageError } = await supabase
        .from('messages')
        .select('reactions, room_id')
        .eq('id', message_id)
        .single();

      if (messageError || !message) {
        logError('Error fetching message for reaction', messageError);
        res.status(404).json({ error: 'Message not found' });
        return;
      }

      // Get current reactions array from message (stored as JSONB in DB)
      // Cast to MessageReaction[] type and provide empty array fallback
      const currentReactions: MessageReaction[] = (message.reactions as MessageReaction[]) || [];

      // Create mutable copy for updates (don't mutate original)
      let updatedReactions: MessageReaction[] = [...currentReactions];

      // Track action type for real-time broadcast (clients need to know if added/removed)
      let action: 'add' | 'remove' = 'add';

      // Check if this emoji reaction already exists on the message
      // Returns index if found, -1 if not found
      const existingReactionIndex = currentReactions.findIndex((r) => r.emoji === emoji);

      if (existingReactionIndex >= 0) {
        // Reaction exists - need to toggle this specific user's reaction
        const existingReaction = currentReactions[existingReactionIndex];

        // Check if this user already reacted with this emoji
        const userIndex = existingReaction.user_ids.indexOf(user_id);

        if (userIndex >= 0) {
          // User already reacted - REMOVE their reaction (toggle off)
          // Remove user from the user_ids array
          existingReaction.user_ids.splice(userIndex, 1);
          // Decrement count (one less person reacted)
          existingReaction.count -= 1;
          action = 'remove'; // Track that we're removing

          // If no users left reacting, remove the entire reaction entry
          // (clean up empty reactions to keep data tidy)
          if (existingReaction.count === 0) {
            updatedReactions = currentReactions.filter((r) => r.emoji !== emoji);
          } else {
            // Update the reaction with new user list and count
            updatedReactions[existingReactionIndex] = existingReaction;
          }
        } else {
          // User hasn't reacted yet - ADD their reaction (toggle on)
          existingReaction.user_ids.push(user_id);
          existingReaction.count += 1; // Increment count
          // Update the reaction in place
          updatedReactions[existingReactionIndex] = existingReaction;
        }
      } else {
        // This emoji reaction doesn't exist yet - create new reaction entry
        const newReaction: MessageReaction = {
          emoji,
          user_ids: [user_id], // Start with this user as the first reactor
          count: 1, // Initial count is 1
        };
        updatedReactions.push(newReaction); // Add to reactions array
      }

      // Update message
      const { error: updateError } = await supabase
        .from('messages')
        .update({
          reactions: updatedReactions,
          updated_at: new Date().toISOString(),
        })
        .eq('id', message_id);

      if (updateError) {
        logError('Error updating message reactions', updateError);
        throw updateError;
      }

      // Broadcast reaction update
      const reactionUpdate: ReactionUpdate = {
        message_id,
        reaction: updatedReactions.find((r) => r.emoji === emoji) || {
          emoji,
          user_ids: [],
          count: 0,
        },
        action,
        user_id,
      };

      try {
        await redisPublisher.publish(
          // Silent fail: if Redis down, reaction saved but clients don't see it
          'reaction_updates',
          JSON.stringify({
            type: 'reaction_update',
            room_id: message.room_id,
            data: reactionUpdate,
          })
        );
      } catch (publishError) {
        logError('Failed to publish reaction update', publishError); // Silent fail: reaction saved but not broadcast
        // Continue without failing
      }

      // Log telemetry
      try {
        await recordTelemetryEvent('reaction_added', {
          room_id: message.room_id,
          user_id,
        });
      } catch (telemetryError) {
        logError('Failed to log telemetry for reaction', telemetryError);
      }

      res.json({ success: true, reactions: updatedReactions, action });
    } catch (error: any) {
      logError('Add reaction error', error);
      res.status(500).json({ error: 'Failed to add reaction' });
    }
  }

  /**
   * SIN-302: Create thread
   */
  async createThread(req: Request, res: Response): Promise<void> {
    try {
      const { parent_message_id, title, initial_message }: CreateThreadRequest = req.body;
      const user_id = (req as any).user?.id;

      if (!parent_message_id || typeof parent_message_id !== 'string') {
        res.status(400).json({ error: 'Invalid parent_message_id' });
        return;
      }

      if (!user_id || typeof user_id !== 'string') {
        res.status(401).json({ error: 'Unauthorized: Missing user_id' });
        return;
      }

      // Get parent message to get room_id
      const { data: parentMessage, error: messageError } = await supabase
        .from('messages')
        .select('room_id, content_preview')
        .eq('id', parent_message_id)
        .single();

      if (messageError || !parentMessage) {
        logError('Error fetching parent message', messageError);
        res.status(404).json({ error: 'Parent message not found' });
        return;
      }

      // Create thread
      const threadTitle =
        title || `Thread: ${(parentMessage.content_preview || '').substring(0, 50)}...`;
      const { data: thread, error: threadError } = await supabase
        .from('threads')
        .insert({
          parent_message_id,
          room_id: parentMessage.room_id,
          title: threadTitle,
          created_by: user_id,
        })
        .select()
        .single();

      if (threadError || !thread) {
        logError('Error creating thread', threadError);
        throw threadError || new Error('Failed to create thread');
      }

      // Create initial thread message if provided
      if (initial_message) {
        const { error: messageError } = await supabase.from('messages').insert({
          room_id: parentMessage.room_id,
          sender_id: user_id,
          content_preview: initial_message,
          thread_id: thread.id,
        });

        if (messageError) {
          logError('Error creating initial message', messageError);
          // Don't fail the thread creation
        }
      }

      // Broadcast thread creation
      try {
        await redisPublisher.publish(
          'thread_updates',
          JSON.stringify({
            type: 'thread_created',
            room_id: parentMessage.room_id,
            data: thread,
          })
        );
      } catch (publishError) {
        logError('Failed to publish thread creation', publishError);
      }

      // Log telemetry
      try {
        await recordTelemetryEvent('thread_created', {
          room_id: parentMessage.room_id,
          user_id,
        });
      } catch (telemetryError) {
        logError('Failed to log telemetry for thread', telemetryError);
      }

      res.status(201).json({ success: true, thread });
    } catch (error: any) {
      logError('Create thread error', error);
      res.status(500).json({ error: 'Failed to create thread' });
    }
  }

  /**
   * SIN-302: Get thread with messages
   * Updated to use cursor-based pagination (Phase 3.2)
   */
  async getThread(req: Request, res: Response): Promise<void> {
    try {
      const { thread_id } = req.params;
      const cursor = req.query.cursor as string | undefined;
      const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);

      if (!thread_id || typeof thread_id !== 'string') {
        res.status(400).json({ error: 'Invalid thread_id' });
        return;
      }

      // Parallelize thread info and messages queries for better performance
      const [threadResult, messagesResult] = await Promise.all([
        // Get thread info with parent message (Supabase foreign key join)
        supabase
          .from('threads')
          .select('*, parent_message:messages(*)')
          .eq('id', thread_id)
          .single(),
        // Get thread messages with cursor-based pagination
        findMany('messages', {
          filter: {
            thread_id,
          },
          orderBy: {
            column: 'created_at',
            ascending: true, // Oldest first (chronological order)
          },
          cursor,
          cursorColumn: 'created_at',
          limit,
        }),
      ]);

      const { data: thread, error: threadError } = threadResult;

      if (threadError || !thread) {
        logError('Error fetching thread', threadError);
        res.status(404).json({ error: 'Thread not found' });
        return;
      }

      // Handle paginated result
      if (Array.isArray(messagesResult)) {
        // Fallback: simple array
        res.json({
          success: true,
          thread,
          messages: messagesResult,
          pagination: {
            limit,
            hasMore: messagesResult.length === limit,
          },
        });
        return;
      }

      const paginatedMessages = messagesResult as PaginatedResult<any>;

      // Fetch user info for messages (findMany doesn't support joins)
      const messagesWithUsers = await Promise.all(
        paginatedMessages.data.map(async (message: any) => {
          if (message.sender_id) {
            const { data: user } = await supabase
              .from('users')
              .select('handle, display_name')
              .eq('id', message.sender_id)
              .single();

            return {
              ...message,
              user: user || null,
            };
          }
          return message;
        })
      );

      res.json({
        success: true,
        thread,
        messages: messagesWithUsers,
        pagination: {
          cursor: paginatedMessages.pagination.cursor,
          prevCursor: paginatedMessages.pagination.prevCursor,
          hasMore: paginatedMessages.pagination.hasMore,
          limit: paginatedMessages.pagination.limit,
        },
      });
    } catch (error: any) {
      logError('Get thread error', error);
      res.status(500).json({ error: 'Failed to fetch thread' });
    }
  }

  /**
   * SIN-302: Get room threads
   * Updated to use cursor-based pagination (Phase 3.2)
   */
  async getRoomThreads(req: Request, res: Response): Promise<void> {
    try {
      const { room_id } = req.params;
      const cursor = req.query.cursor as string | undefined;
      const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);

      if (!room_id || typeof room_id !== 'string') {
        res.status(400).json({ error: 'Invalid room_id' });
        return;
      }

      // Use cursor-based pagination via findMany helper
      // Note: findMany doesn't support joins, so we'll query threads first, then fetch parent messages
      const result = await findMany<Thread>('threads', {
        filter: {
          room_id,
          is_archived: false,
        },
        orderBy: {
          column: 'updated_at',
          ascending: false,
        },
        cursor,
        cursorColumn: 'updated_at',
        limit,
        includeTotal: true, // Include total count for backward compatibility
      });

      // Check if result is paginated (cursor-based) or simple array (backward compat)
      if (Array.isArray(result)) {
        // Fallback: simple array (shouldn't happen with cursor)
        res.json({
          success: true,
          threads: result,
          pagination: {
            limit,
            has_more: result.length === limit,
          },
        });
        return;
      }

      const paginatedResult = result as PaginatedResult<Thread>;

      // Fetch parent message previews for each thread
      // Since findMany doesn't support joins, we need to fetch parent messages separately
      const threadsWithParentMessages = await Promise.all(
        paginatedResult.data.map(async (thread: any) => {
          if (thread.parent_message_id) {
            const { data: parentMessage } = await supabase
              .from('messages')
              .select('content_preview')
              .eq('id', thread.parent_message_id)
              .single();

            return {
              ...thread,
              parent_message: parentMessage || null,
            };
          }
          return thread;
        })
      );

      res.json({
        success: true,
        threads: threadsWithParentMessages,
        pagination: {
          cursor: paginatedResult.pagination.cursor,
          prevCursor: paginatedResult.pagination.prevCursor,
          hasMore: paginatedResult.pagination.hasMore,
          limit: paginatedResult.pagination.limit,
          total: paginatedResult.pagination.total,
        },
      });
    } catch (error: any) {
      logError('Get room threads error', error);
      res.status(500).json({ error: 'Failed to fetch room threads' });
    }
  }

  /**
   * SIN-401: Edit message
   */
  async editMessage(req: Request, res: Response): Promise<void> {
    try {
      const { message_id } = req.params;
      const { content, user_id } = req.body;

      if (!message_id || typeof message_id !== 'string') {
        res.status(400).json({ error: 'Invalid message_id' });
        return;
      }

      if (!content || typeof content !== 'string') {
        res.status(400).json({ error: 'Invalid content' });
        return;
      }

      if (!user_id || typeof user_id !== 'string') {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      // Get current message
      const { data: message, error: messageError } = await supabase
        .from('messages')
        .select('sender_id, room_id, content_preview')
        .eq('id', message_id)
        .single();

      if (messageError || !message) {
        res.status(404).json({ error: 'Message not found' });
        return;
      }

      // Verify ownership
      if (message.sender_id !== user_id) {
        res.status(403).json({ error: 'Not authorized to edit this message' });
        return;
      }

      // Check 24-hour edit window (Discord-like policy)
      // Prevents editing very old messages which could confuse conversation context
      const { data: messageWithTime } = await supabase
        .from('messages')
        .select('created_at') // Only need timestamp for age check
        .eq('id', message_id)
        .single();

      if (messageWithTime) {
        // Calculate age of message in hours
        const createdAt = new Date(messageWithTime.created_at); // Parse ISO timestamp
        // Date.now() = current time in ms, createdAt.getTime() = message time in ms
        // Difference in ms / (1000 ms/sec * 60 sec/min * 60 min/hr) = hours
        const hoursSinceCreation = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60);

        // Reject edits after 24 hours (policy: prevent editing ancient history)
        if (hoursSinceCreation > 24) {
          res.status(400).json({ error: 'Message can only be edited within 24 hours' });
          return;
        }
      }

      // Update message content (database trigger will automatically create edit_history entry)
      // content_preview is limited to 512 chars (database column constraint)
      // substring(0, 512) ensures we don't exceed limit (truncates if longer)
      const { error: updateError } = await supabase
        .from('messages')
        .update({
          content_preview: content.substring(0, 512), // Truncate to max length (database constraint)
          updated_at: new Date().toISOString(), // Update timestamp (ISO format for Supabase)
        })
        .eq('id', message_id); // Only update this specific message

      if (updateError) {
        logError('Error updating message', updateError); // Silent fail: edit_history trigger may have fired before update failed
        throw updateError;
      }

      // Broadcast edit
      try {
        await redisPublisher.publish(
          // Silent fail: edit saved but not broadcast if Redis down
          'message_updates',
          JSON.stringify({
            type: 'message_edited',
            room_id: message.room_id,
            data: { message_id, content },
          })
        );
      } catch (publishError) {
        logError('Failed to publish message edit', publishError);
      }

      res.json({ success: true, message_id });
    } catch (error: any) {
      logError('Edit message error', error);
      res.status(500).json({ error: 'Failed to edit message' });
    }
  }

  /**
   * SIN-401: Delete message
   */
  async deleteMessage(req: Request, res: Response): Promise<void> {
    try {
      const { message_id } = req.params;
      const user_id = (req as any).user?.id;

      if (!message_id || typeof message_id !== 'string') {
        res.status(400).json({ error: 'Invalid message_id' });
        return;
      }

      if (!user_id || typeof user_id !== 'string') {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      // Get message to verify ownership and get room_id
      const { data: message, error: messageError } = await supabase
        .from('messages')
        .select('sender_id, room_id, created_at')
        .eq('id', message_id)
        .single();

      if (messageError || !message) {
        res.status(404).json({ error: 'Message not found' });
        return;
      }

      // Verify ownership or admin
      if (message.sender_id !== user_id) {
        // Check if user is admin/mod (would need to check room_memberships)
        res.status(403).json({ error: 'Not authorized to delete this message' });
        return;
      }

      // Check 24-hour deletion window (same policy as editing)
      // Prevents deletion of old messages that might be referenced in conversation
      const createdAt = new Date(message.created_at);
      // Calculate age: (current time - creation time) / milliseconds per hour
      const hoursSinceCreation = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60);

      // Reject deletions after 24 hours (policy: preserve conversation history)
      if (hoursSinceCreation > 24) {
        res.status(400).json({ error: 'Message can only be deleted within 24 hours' });
        return;
      }

      // Delete message
      const { error: deleteError } = await supabase.from('messages').delete().eq('id', message_id);

      if (deleteError) {
        logError('Error deleting message', deleteError);
        throw deleteError;
      }

      // Broadcast deletion
      try {
        await redisPublisher.publish(
          // Silent fail: deletion saved but not broadcast if Redis down
          'message_updates',
          JSON.stringify({
            type: 'message_deleted',
            room_id: message.room_id,
            data: { message_id },
          })
        );
      } catch (publishError) {
        logError('Failed to publish message deletion', publishError); // Silent fail: deletion saved but clients don't see it
      }

      res.json({ success: true, message_id });
    } catch (error: any) {
      logError('Delete message error', error);
      res.status(500).json({ error: 'Failed to delete message' });
    }
  }

  /**
   * SIN-402: Search messages
   * Updated to support cursor-based pagination (Phase 3.2)
   * Note: Full-text search uses limit/offset fallback when cursor not provided for backward compatibility
   */
  async searchMessages(req: Request, res: Response): Promise<void> {
    try {
      const { q, room_id } = req.query;
      const cursor = req.query.cursor as string | undefined;
      const page = parseInt(req.query.page as string) || (cursor ? undefined : 1);
      const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);

      if (!q || typeof q !== 'string' || q.trim().length === 0) {
        res.status(400).json({ error: 'Invalid search query' });
        return;
      }

      // Build search query using PostgreSQL full-text search
      let query = supabase.from('message_search_index').select('*').textSearch('search_vector', q, {
        type: 'websearch',
        config: 'english',
      });

      // Optionally filter by room
      if (room_id && typeof room_id === 'string') {
        query = query.eq('room_id', room_id);
      }

      // Use cursor-based pagination if cursor provided, otherwise fallback to limit/offset
      if (cursor) {
        // Cursor-based pagination: filter by created_at < cursor (for DESC order)
        const cursorDate = new Date(cursor);
        query = query.lt('created_at', cursorDate.toISOString());
      } else if (page) {
        // Fallback: limit/offset pagination for backward compatibility
        const offset = (page - 1) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      // Execute search ordered by created_at DESC (newest first)
      const {
        data: results,
        error,
        count,
      } = await query.order('created_at', { ascending: false }).limit(limit + 1); // Fetch one extra to check if more exists

      if (error) {
        logError('Error searching messages', error);
        throw error;
      }

      const resultsArray = results || [];
      const hasMore = resultsArray.length > limit;
      const actualResults = hasMore ? resultsArray.slice(0, limit) : resultsArray;

      // Calculate next cursor from last result
      let nextCursor: string | undefined;
      if (hasMore && actualResults.length > 0) {
        const lastResult = actualResults[actualResults.length - 1] as any;
        if (lastResult.created_at) {
          nextCursor = new Date(lastResult.created_at).toISOString();
        }
      }

      // Return pagination metadata
      if (cursor || nextCursor) {
        // Cursor-based pagination response
        res.json({
          success: true,
          results: actualResults,
          pagination: {
            cursor: nextCursor,
            prevCursor: cursor,
            hasMore,
            limit,
            total: count || undefined,
          },
        });
      } else {
        // Limit/offset pagination response (backward compatibility)
        const offset = page ? (page - 1) * limit : 0;
        res.json({
          success: true,
          results: actualResults,
          pagination: {
            page: page || 1,
            limit,
            total: count || 0,
            has_more: (count || 0) > offset + limit,
          },
        });
      }
    } catch (error: any) {
      logError('Search messages error', error);
      res.status(500).json({ error: 'Failed to search messages' });
    }
  }
}

export const messagesController = new MessagesController();
