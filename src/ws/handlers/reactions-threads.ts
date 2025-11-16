/**
 * WebSocket handlers for reactions and threads
 * SIN-203, SIN-303: Real-time reaction and thread updates
 */

import { WebSocket } from 'ws';
import { redisSubscriber } from '../../config/redis-pubsub.js';
import { logInfo, logError } from '../../shared/logger.js';

let isSubscribed = false;

/**
 * Setup Redis subscriptions for reactions and threads
 */
export function setupReactionThreadSubscriptions(io: any) {
  if (isSubscribed) {
    return; // Already subscribed
  }

  // Subscribe to reaction updates
  redisSubscriber.subscribe('reaction_updates', (err: Error | null) => {
    if (err) {
      logError('Failed to subscribe to reaction_updates', err);
    } else {
      logInfo('Subscribed to reaction_updates channel');
    }
  });

  // Subscribe to thread updates
  redisSubscriber.subscribe('thread_updates', (err: Error | null) => {
    if (err) {
      logError('Failed to subscribe to thread_updates', err);
    } else {
      logInfo('Subscribed to thread_updates channel');
    }
  });

  // Subscribe to message updates (edits/deletes)
  redisSubscriber.subscribe('message_updates', (err: Error | null) => {
    if (err) {
      logError('Failed to subscribe to message_updates', err);
    } else {
      logInfo('Subscribed to message_updates channel');
    }
  });

  // Handle Redis messages
  redisSubscriber.on('message', (channel: string, message: string) => {
    try {
      const data = JSON.parse(message); // Silent fail: malformed JSON throws, message lost

      switch (channel) {
        case 'reaction_updates':
          if (data.type === 'reaction_update' && data.room_id) {
            // Broadcast to all clients in the room
            io.to(`room:${data.room_id}`).emit('reaction_update', data.data);
          }
          break;

        case 'thread_updates':
          if (data.type === 'thread_created' && data.room_id) {
            io.to(`room:${data.room_id}`).emit('thread_created', data.data);
          } else if (data.type === 'thread_message' && data.room_id) {
            io.to(`room:${data.room_id}`).emit('thread_message', data.data);
          }
          break;

        case 'message_updates':
          if (data.type === 'message_edited' && data.room_id) {
            io.to(`room:${data.room_id}`).emit('message_edited', data.data);
          } else if (data.type === 'message_deleted' && data.room_id) {
            io.to(`room:${data.room_id}`).emit('message_deleted', data.data);
          }
          break;
      }
    } catch (error: any) {
      logError('Error processing Redis message', error);
    }
  });

  isSubscribed = true;
}

/**
 * Handle reaction add via WebSocket
 */
export function handleReactionAdd(ws: WebSocket, data: any) {
  try {
    if (!data.message_id || !data.emoji || !data.user_id) {
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Invalid reaction data',
      }));
      return;
    }

    // Emit to Redis for processing
    // The actual reaction logic is handled by the HTTP endpoint
    // This is just for real-time broadcasting
    logInfo(`Reaction add request: ${data.emoji} on message ${data.message_id}`);
  } catch (error: any) {
    logError('Error handling reaction add', error);
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Failed to process reaction',
    }));
  }
}

/**
 * Handle thread creation via WebSocket
 */
export function handleThreadCreate(ws: WebSocket, data: any) {
  try {
    if (!data.parent_message_id || !data.room_id) {
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Invalid thread data',
      }));
      return;
    }

    logInfo(`Thread creation request for message ${data.parent_message_id}`);
  } catch (error: any) {
    logError('Error handling thread create', error);
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Failed to process thread creation',
    }));
  }
}

