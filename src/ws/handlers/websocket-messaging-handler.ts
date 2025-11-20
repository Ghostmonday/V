/**
 * Handle messaging WSEnvelope and publish to Redis room channel
 *
 * When a client sends a message via WebSocket:
 * 1. Check rate limit (max 15 messages per 30 seconds)
 * 2. Publish message to Redis channel for other servers/clients
 * 3. Send acknowledgment back to sender
 * 4. Handle moderation hooks (sentiment flagging, banned words)
 */

import { WebSocket } from 'ws';
import crypto from 'crypto';
import { getRedisClient } from '../../config/database-config.js';
import { broadcastToRoom } from '../websocket-utils.js';
import { checkMessageRateLimit } from '../../middleware/rate-limiting/websocket-message-rate-limiter-middleware.js';
import { scanForToxicity } from '../../services/moderation-service.js';
import { logError, logInfo } from '../../shared/logger-shared.js';
import { validateWSMessage } from '../../middleware/validation/incremental-validation-middleware.js';
import { isEncryptedPayload, isE2ERoom } from '../../services/e2e-encryption.js';
import { publishToStream, routeToModeration } from '../../config/redis-streams-config.js';
import { z } from 'zod';

const redis = getRedisClient();

// WebSocket envelope validation schema
const wsEnvelopeSchema = z.object({
  type: z.string(),
  room_id: z.string().uuid(),
  msg_id: z.string().uuid().optional(),
  payload: z
    .object({
      content: z.string().optional(),
      text: z.string().optional(),
    })
    .optional(),
});

export async function handleMessaging(ws: WebSocket & { userId?: string }, envelope: any) {
  try {
    // VALIDATION POINT 1: Validate WebSocket envelope structure
    const validatedEnvelope = validateWSMessage(envelope, wsEnvelopeSchema) as any;

    // VALIDATION POINT 2: Validate userId if present
    const userId = ws.userId;
    if (userId && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(userId)) {
      ws.send(JSON.stringify({ type: 'error', msg: 'invalid_user_id' }));
      return;
    }

    // VALIDATION POINT 3: Validate roomId format
    const roomId = validatedEnvelope.room_id;
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(roomId)) {
      ws.send(JSON.stringify({ type: 'error', msg: 'invalid_room_id' }));
      return;
    }

    // VALIDATION POINT 4: Validate message content exists and is valid
    const messageContent =
      validatedEnvelope.payload?.content || validatedEnvelope.payload?.text || '';
    if (
      !messageContent ||
      typeof messageContent !== 'string' ||
      messageContent.trim().length === 0
    ) {
      ws.send(JSON.stringify({ type: 'error', msg: 'empty_message' }));
      return;
    }

    // VALIDATION POINT 4.5: Validate encryption for E2E rooms
    // Check if room requires encryption and validate payload is encrypted
    try {
      const { getRoom } = await import('../../services/room-service.js');
      const room = await getRoom(roomId);

      if (room && isE2ERoom(room)) {
        // Room requires E2E encryption - validate payload is encrypted
        if (!isEncryptedPayload(messageContent)) {
          ws.send(
            JSON.stringify({
              type: 'error',
              msg: 'encryption_required',
              reason:
                'This room requires end-to-end encryption. Message payload must be encrypted.',
            })
          );
          return;
        }
      }
    } catch (error) {
      // Non-critical: if we can't check room config, allow message but log warning
      logError(
        'Failed to check room encryption requirement',
        error instanceof Error ? error : new Error(String(error))
      );
    }

    // VALIDATION POINT 5: Validate message length
    // For encrypted messages, allow longer payloads (encryption adds overhead)
    const maxLength = isEncryptedPayload(messageContent) ? 20000 : 10000;
    if (messageContent.length > maxLength) {
      ws.send(JSON.stringify({ type: 'error', msg: 'message_too_long', maxLength }));
      return;
    }

    // VALIDATION POINT 6: Rate limiting validation (validates user can send)
    if (userId) {
      const rateLimit = await checkMessageRateLimit(userId, roomId);

      // Validate rate limit response structure
      if (!rateLimit || typeof rateLimit !== 'object' || typeof rateLimit.allowed !== 'boolean') {
        logError('Invalid rate limit response', { rateLimit });
        ws.send(JSON.stringify({ type: 'error', msg: 'rate_limit_check_failed' }));
        return;
      }

      if (!rateLimit.allowed) {
        ws.send(
          JSON.stringify({
            type: 'error',
            msg: 'rate_limit_exceeded',
            reason: rateLimit.reason,
            resetAt: rateLimit.resetAt.toISOString(),
            remaining: rateLimit.remaining,
          })
        );
        return;
      }
    }

    // VALIDATION POINT 7: Moderation hooks with validation
    try {
      if (messageContent && userId && roomId) {
        const toxicityCheck = await scanForToxicity(
          messageContent,
          roomId,
          validatedEnvelope.msg_id,
          userId
        );

        // VALIDATION POINT 8: Validate moderation scan result
        if (!toxicityCheck || typeof toxicityCheck !== 'object') {
          logError('Invalid toxicity check result', { toxicityCheck });
        } else if (
          typeof toxicityCheck.isToxic !== 'boolean' ||
          typeof toxicityCheck.score !== 'number'
        ) {
          logError('Invalid toxicity check structure', { toxicityCheck });
        } else if (toxicityCheck.isToxic) {
          // Message is toxic - send warning but still allow (moderation service handles warnings/mutes)
          ws.send(
            JSON.stringify({
              type: 'moderation_warning',
              msg_id: validatedEnvelope.msg_id,
              score: toxicityCheck.score,
              suggestion: toxicityCheck.suggestion || 'Please keep conversations respectful',
            })
          );
          // Message continues to be broadcast (moderation service handles user warnings/mutes)
        }
      }
    } catch (error: any) {
      // Non-critical: log but don't block message
      logError('Moderation check failed', error);
    }

    // VALIDATION POINT 9: Validate broadcast payload before sending
    // Generate message ID if not provided (required for delivery tracking)
    const messageId = validatedEnvelope.msg_id || crypto.randomUUID();
    const broadcastPayload = {
      type: 'message',
      id: messageId,
      payload: validatedEnvelope.payload,
      sender_id: userId,
      room_id: roomId,
      created_at: new Date().toISOString(),
      requires_ack: true, // Flag to indicate client should send delivery ack
    };

    // Validate payload structure
    if (!broadcastPayload.id || !broadcastPayload.payload) {
      ws.send(JSON.stringify({ type: 'error', msg: 'invalid_broadcast_payload' }));
      return;
    }

    // Track message as pending delivery for all room participants
    // This allows retry logic if acknowledgements are not received
    if (userId && messageId) {
      import('../../services/message-delivery-service.js').then(({ trackMessageDelivery }) => {
        // Track initial delivery status as pending
        trackMessageDelivery(messageId, userId, 'pending').catch((err) => {
          logError('Failed to track message delivery', err);
        });
      });
    }

    // Phase 9.2: Publish to Redis Stream for message routing and archival
    try {
      await publishToStream(roomId, {
        message_id: messageId,
        ...broadcastPayload,
        stream_timestamp: Date.now(),
      });

      // Route to moderation stream if needed
      if (userId && messageContent) {
        await routeToModeration(roomId, messageId, {
          content: messageContent,
          sender_id: userId,
        }).catch((err) => {
          logError('Failed to route to moderation stream', err);
        });
      }
    } catch (streamError) {
      // Non-critical: log but don't block message broadcast
      logError(
        'Failed to publish to Redis Stream',
        streamError instanceof Error ? streamError : new Error(String(streamError))
      );
    }

    // Broadcast message to room using optimized WebSocket utility
    // Uses direct WebSocket broadcast for efficiency, falls back to Redis pub/sub
    broadcastToRoom(
      roomId,
      broadcastPayload,
      true // Use direct broadcast for efficiency
    );

    // VALIDATION POINT 10: Validate acknowledgment payload
    const ackPayload = {
      type: 'msg_ack',
      msg_id: messageId,
      status: 'published', // Message published to room (not yet delivered to all clients)
      published_at: new Date().toISOString(),
    };

    // VALIDATION CHECKPOINT: Validate ack payload structure
    if (!messageId || typeof messageId !== 'string') {
      ws.send(JSON.stringify({ type: 'error', msg: 'invalid_message_id' }));
      return;
    }

    // Send acknowledgment back to sender with publication confirmation
    // Confirms message was received and published (client can show "sent" status)
    // Actual delivery to recipients will be tracked via client-side acks
    ws.send(JSON.stringify(ackPayload));
  } catch (error: any) {
    // VALIDATION POINT 11: Error handling with validation
    if (error instanceof Error) {
      logError('WebSocket message handling error', error);
      ws.send(
        JSON.stringify({
          type: 'error',
          msg: 'message_processing_failed',
          error: error.message,
        })
      );
    } else {
      logError('Unknown error in WebSocket handler', error);
      ws.send(JSON.stringify({ type: 'error', msg: 'unknown_error' }));
    }
  }
}
