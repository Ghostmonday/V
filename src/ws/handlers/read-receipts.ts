/**
 * WebSocket handler for read receipts
 * Handles real-time read receipt updates
 */

import { WebSocket } from 'ws';
import { markRead, markDelivered } from '../../services/read-receipts-service.js';
import { broadcastToRoom } from '../utils.js';
import { logError } from '../../shared/logger.js';

/**
 * Handle read receipt WebSocket message
 * Message format: { type: 'read_receipt', message_id: '...', action: 'read' | 'delivered' }
 */
export function handleReadReceipt(ws: WebSocket, envelope: any) {
  try {
    const { message_id, action, room_id, user_id } = envelope.payload || {};

    if (!message_id || !action || !user_id) {
      ws.send(JSON.stringify({
        type: 'error',
        msg: 'Missing required fields: message_id, action, user_id'
      }));
      return;
    }

    // Handle different receipt actions
    switch (action) {
      case 'read':
      case 'seen':
        markRead(message_id, user_id).then(() => {
          // Broadcast read receipt to room
          if (room_id) {
            broadcastToRoom(
              room_id,
              {
                type: 'read_receipt',
                message_id,
                user_id,
                action: 'read',
                timestamp: Date.now()
              },
              true
            );
          }
          // Send acknowledgment
          ws.send(JSON.stringify({
            type: 'receipt_ack',
            message_id,
            action: 'read'
          }));
        }).catch((error) => {
          logError('Failed to mark message as read', error);
          ws.send(JSON.stringify({
            type: 'error',
            msg: 'Failed to mark message as read'
          }));
        });
        break;

      case 'delivered':
        markDelivered(message_id, user_id).then(() => {
          // Broadcast delivery receipt to room
          if (room_id) {
            broadcastToRoom(
              room_id,
              {
                type: 'read_receipt',
                message_id,
                user_id,
                action: 'delivered',
                timestamp: Date.now()
              },
              true
            );
          }
          // Send acknowledgment
          ws.send(JSON.stringify({
            type: 'receipt_ack',
            message_id,
            action: 'delivered'
          }));
        }).catch((error) => {
          logError('Failed to mark message as delivered', error);
          ws.send(JSON.stringify({
            type: 'error',
            msg: 'Failed to mark message as delivered'
          }));
        });
        break;

      default:
        ws.send(JSON.stringify({
          type: 'error',
          msg: `Unknown receipt action: ${action}`
        }));
    }
  } catch (error: any) {
    logError('Read receipt handler error', error);
    ws.send(JSON.stringify({
      type: 'error',
      msg: 'Invalid read receipt message format'
    }));
  }
}

