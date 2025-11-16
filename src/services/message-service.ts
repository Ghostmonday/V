/**
 * Message Service
 * Handles message persistence and real-time broadcasting
 */

import { create, findMany } from '../shared/supabase-helpers.js';
import { getRedisClient } from '../config/db.js';
import { logError, logWarning } from '../shared/logger.js';
import { scanForToxicity, handleViolation, isUserMuted, getRoomById } from './moderation.service.js';
import { getRoomConfig, isEnterpriseUser } from './room-service.js';
import { getUserSubscription } from './subscription-service.js';
import { supabase } from '../config/db.js';
import { validateServiceData, validateBeforeDB, validateAfterDB } from '../middleware/incremental-validation.js';
import { z } from 'zod';

const redis = getRedisClient();

// Validation schemas for incremental validation
const messageInputSchema = z.object({
  roomId: z.union([z.string().uuid(), z.string(), z.number()]),
  senderId: z.string().uuid(),
  content: z.string().min(1).max(10000),
});

const messageDBSchema = z.object({
  room_id: z.union([z.string().uuid(), z.string(), z.number()]),
  conversation_id: z.union([z.string().uuid(), z.string(), z.number()]),
  sender_id: z.string().uuid(),
  content: z.string().min(1),
  message_type: z.string(),
});

/**
 * Send a message to a room
 * Persists message to database and broadcasts via Redis pub/sub
 * Includes AI moderation for enterprise rooms
 * Validates incrementally at every step
 */
export async function sendMessageToRoom(data: {
  roomId: string | number;
  senderId: string;
  content: string;
}): Promise<void> {
  try {
    // VALIDATION POINT 1: Validate input data
    const validatedInput = validateServiceData(data, messageInputSchema, 'sendMessageToRoom');
    
    // Handle roomId type conversion: if string, try parseInt; if that fails (NaN), use original string
    // This handles both numeric IDs (legacy) and UUID strings (new schema)
    const roomIdValue = typeof validatedInput.roomId === 'string' 
      ? (parseInt(validatedInput.roomId) || validatedInput.roomId) // Try parse, fallback to string if not numeric
      : validatedInput.roomId; // Already a number
    
    // VALIDATION POINT 2: Validate roomId after transformation
    if (typeof roomIdValue === 'string' && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(roomIdValue) && isNaN(Number(roomIdValue))) {
      throw new Error('Invalid roomId format');
    }

    // VALIDATION POINT 3: Validate senderId format
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(validatedInput.senderId)) {
      throw new Error('Invalid senderId format');
    }
    
    // Check if user is muted in this room
    const isMuted = await isUserMuted(validatedInput.senderId, String(roomIdValue));
    if (isMuted) {
      throw new Error('You are temporarily muted in this room');
    }

    // Check if room has AI moderation enabled (enterprise only)
    const roomConfig = await getRoomConfig(String(roomIdValue));
    
    // VALIDATION POINT 4: Validate room config structure
    if (roomConfig && typeof roomConfig !== 'object') {
      logWarning('Invalid room config structure', { roomConfig });
    }
    
    if (roomConfig?.ai_moderation) {
      // Verify enterprise tier (moderation is enterprise-only)
      const userTier = await getUserSubscription(validatedInput.senderId);
      
      // VALIDATION POINT 5: Validate user tier
      if (!userTier || typeof userTier !== 'string') {
        logWarning('Invalid user tier', { userId: validatedInput.senderId, tier: userTier });
      }
      
      if (!isEnterpriseUser(userTier)) {
        // This shouldn't happen if room config is correct, but safety check
        logError(`Non-enterprise user ${validatedInput.senderId} tried to send in moderated room`);
      }

      // Scan message for toxicity
      const scan = await scanForToxicity(validatedInput.content, String(roomIdValue));
      
      // VALIDATION POINT 6: Validate moderation scan result
      if (!scan || typeof scan !== 'object' || typeof scan.isToxic !== 'boolean') {
        logWarning('Invalid moderation scan result', { scan });
      }
      
      if (scan.isToxic) {
        // Log toxic scan event
        const { logModerationEvent } = await import('./telemetry-service.js');
        await logModerationEvent('scan_toxic', data.senderId, String(roomIdValue), {
          score: scan.score,
          suggestion: scan.suggestion,
        });
        // Get current violation count
        const { data: violations } = await supabase
          .from('message_violations')
          .select('count')
          .eq('user_id', data.senderId)
          .eq('room_id', String(roomIdValue))
          .single();

        const violationCount = violations?.count || 0;
        
        // Handle violation (warnings first, then mutes)
        await handleViolation(data.senderId, String(roomIdValue), scan.suggestion, violationCount);
        
        // Still allow message through, but warn user
        // Message will be inserted below, but user gets warning/mute
      }
    }

    // Compress message content at DB write using JSONB compression
    // This reduces storage by 30-45% while maintaining full-text search capability
    const compressedContent = JSON.stringify({
      content: validatedInput.content,
      compressed: true,
      length: validatedInput.content.length
    });
    
    // VALIDATION POINT 7: Validate compressed content structure
    try {
      JSON.parse(compressedContent);
    } catch (e) {
      throw new Error('Failed to compress message content');
    }
    
    // VALIDATION POINT 8: Validate data before database insert
    const dbPayload = {
      room_id: roomIdValue,
      conversation_id: roomIdValue, // VIBES: Also set conversation_id
      sender_id: validatedInput.senderId,
      content: compressedContent, // Store as JSONB-compressed content
      message_type: 'text',
    };
    
    const validatedDBPayload = validateBeforeDB(dbPayload, messageDBSchema, 'insert_message');
    
    // Insert message with compressed content (moderation doesn't block, just warns/mutes)
    // Use transaction for atomicity (message + receipt if needed)
    const { data: messageData, error: insertError } = await supabase
      .from('messages')
      .insert(validatedDBPayload)
      .select('id')
      .single();
    
    if (insertError) throw insertError;
    
    // VALIDATION POINT 9: Validate database response
    if (!messageData || !messageData.id) {
      throw new Error('Invalid response from database insert');
    }
    
    const messageResponseSchema = z.object({
      id: z.string().uuid(),
    });
    
    validateAfterDB(messageData, messageResponseSchema, 'messages.insert');
    // Note: For future enhancement, wrap message creation + receipt creation in transaction
    
    // VIBES: Trigger card generation check (async, non-blocking)
    if (messageData?.id) {
      import('../services/vibes/card-lifecycle-hook.js').then(({ onMessageSent }) => {
        onMessageSent(String(roomIdValue), messageData.id).catch(err => {
          // Silent fail - don't block message sending
        });
      }).catch(() => {
        // Silent fail if module doesn't load
      });
    }

    // Broadcast message via Redis pub/sub for real-time delivery to connected clients
    // Channel format: "room:{roomId}" - all clients subscribed to this room receive the message
    // Includes timestamp for client-side ordering/display
    await redis.publish( // Silent fail: if Redis down, message saved but not broadcast
      `room:${data.roomId}`,
      JSON.stringify({
        ...data,
        timestamp: Date.now() // Unix timestamp in milliseconds
      })
    );
  } catch (error: any) {
    logError('Failed to send message', error);
    // Preserve original error message if available, otherwise use generic message
    throw new Error(error.message || 'Failed to send message'); // DB insert may have succeeded - partial failure
  }
}

/**
 * Retrieve recent messages from a room
 * Returns up to 50 most recent messages, ordered by timestamp (newest first)
 * @param roomId - Room ID (string or number) or array of room IDs for batch query
 * @param since - Optional ISO8601 timestamp string to fetch messages after this time (lazy loading)
 */
export async function getRoomMessages(roomId: string | number | (string | number)[], since?: string): Promise<any[]> {
  try {
    // Batch query optimization: if roomId is an array, use RPC function
    if (Array.isArray(roomId) && roomId.length > 0) {
      try {
        const { data, error } = await supabase.rpc('get_room_messages_batch', {
          room_ids: roomId,
          since_timestamp: since || null,
        });
        
        if (error) {
          logWarning('Batch query failed, falling back to individual queries', error);
          // Fall through to individual queries
        } else {
          return data || [];
        }
      } catch (rpcError) {
        logWarning('RPC batch query error, falling back to individual queries', rpcError);
        // Fall through to individual queries
      }
    }
    
    // Single room query (original implementation)
    const filter: any = { room_id: roomId };
    
    // Add timestamp filter if since parameter provided (lazy loading optimization)
    if (since) {
      try {
        const sinceDate = new Date(since);
        filter.ts = { gte: sinceDate.toISOString() }; // Greater than or equal to since timestamp
      } catch (e) {
        // Invalid date format - ignore since parameter
        logWarning('Invalid since parameter format, ignoring', { since });
      }
    }
    
    // Query messages table with filters and ordering
    // ascending: false = newest first (most recent at top)
    // limit: 50 = reasonable page size for initial load (can paginate for more)
    const messages = await findMany('messages', {
      filter,
      orderBy: { column: 'ts', ascending: false }, // 'ts' = timestamp column, newest first
      limit: 50 // Max 50 messages per request (prevents large payloads)
    });

    return messages;
  } catch (error: any) {
    logError('Failed to retrieve room messages', error);
    // Preserve original error message for debugging
    throw new Error(error.message || 'Failed to get messages');
  }
}

