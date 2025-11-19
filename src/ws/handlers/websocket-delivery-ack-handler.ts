/**
 * Handle delivery acknowledgements from clients
 * Clients send acks when they receive messages to confirm delivery
 */

import { WebSocket } from 'ws';
import { handleDeliveryAck } from '../../services/message-delivery-service.js';
import { logError } from '../../shared/logger-shared.js';
import { z } from 'zod/v3';

// Delivery ack validation schema
const deliveryAckSchema = z.object({
  type: z.literal('delivery_ack'),
  msg_id: z.string().uuid(),
  user_id: z.string().uuid().optional(), // Optional, can be inferred from WebSocket
});

export async function handleDeliveryAckMessage(
  ws: WebSocket & { userId?: string },
  envelope: any
): Promise<void> {
  try {
    // VALIDATION CHECKPOINT: Validate envelope structure
    const validated = deliveryAckSchema.safeParse(envelope);
    if (!validated.success) {
      ws.send(
        JSON.stringify({
          type: 'error',
          msg: 'invalid_delivery_ack_format',
          errors: validated.error.errors,
        })
      );
      return;
    }

    const { msg_id, user_id } = validated.data;
    const userId = user_id || ws.userId;

    // VALIDATION CHECKPOINT: Validate user ID present
    if (!userId) {
      ws.send(
        JSON.stringify({
          type: 'error',
          msg: 'user_id_required',
        })
      );
      return;
    }

    // VALIDATION CHECKPOINT: Validate message ID format
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(msg_id)) {
      ws.send(
        JSON.stringify({
          type: 'error',
          msg: 'invalid_message_id_format',
        })
      );
      return;
    }

    // Handle the delivery acknowledgement
    await handleDeliveryAck(msg_id, userId);

    // Send confirmation back to client
    ws.send(
      JSON.stringify({
        type: 'delivery_ack_confirmed',
        msg_id,
        confirmed_at: new Date().toISOString(),
      })
    );
  } catch (error: any) {
    logError('Failed to handle delivery ack', error);
    ws.send(
      JSON.stringify({
        type: 'error',
        msg: 'delivery_ack_failed',
        error: error.message,
      })
    );
  }
}
