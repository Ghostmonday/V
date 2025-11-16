/**
 * Handle presence WSEnvelope
 * 
 * Updates user's online/offline status when they connect/disconnect via WebSocket.
 * Presence is stored in Redis for fast lookups across all server instances.
 */

import { WebSocket } from 'ws';
import { updatePresence } from '../../services/presence-service.js';

export function handlePresence(ws: WebSocket, envelope: any) {
  // Extract sender ID (handle both naming conventions for compatibility)
  // envelope.sender_id = protobuf field name, envelope.senderId = camelCase variant
  const senderId = envelope.sender_id || envelope.senderId;
  
  // Update user presence to 'online' in Redis
  // This is used to show "User is online" status in UI
  // .catch() prevents presence update failures from crashing WebSocket handler
  updatePresence(senderId, 'online').catch(() => {
    // Silent fail: presence update lost, user shows offline
  });
  
  // Send acknowledgment back to client
  // Confirms presence update was received
  ws.send(JSON.stringify({ type: 'presence_ack', msg_id: envelope.msg_id }));
}

