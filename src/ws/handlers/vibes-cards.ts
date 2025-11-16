/**
 * VIBES Card WebSocket Handlers
 * Real-time events for card generation, claims, etc.
 */

import { WebSocket } from 'ws';
import { getCard } from '../../services/vibes/card-generator.js';
import { getCardOwnership } from '../../services/vibes/ownership-service.js';
import { logError } from '../../shared/logger.js';

export interface CardEvent {
  type: 'card_generated' | 'card_offered' | 'card_claimed' | 'card_declined' | 'card_expired';
  card_id: string;
  conversation_id: string;
  data?: any;
}

/**
 * Handle card-related WebSocket messages
 */
export async function handleCardEvent(ws: WebSocket, event: CardEvent): Promise<void> {
  try {
    switch (event.type) {
      case 'card_generated':
        await handleCardGenerated(ws, event);
        break;
      case 'card_offered':
        await handleCardOffered(ws, event);
        break;
      case 'card_claimed':
        await handleCardClaimed(ws, event);
        break;
      case 'card_declined':
        await handleCardDeclined(ws, event);
        break;
      case 'card_expired':
        await handleCardExpired(ws, event);
        break;
      default:
        ws.send(JSON.stringify({ error: 'Unknown card event type' }));
    }
  } catch (error) {
    logError('Failed to handle card event', error);
    ws.send(JSON.stringify({ error: 'Failed to process card event' }));
  }
}

async function handleCardGenerated(ws: WebSocket, event: CardEvent): Promise<void> {
  const card = await getCard(event.card_id);
  if (card) {
    ws.send(JSON.stringify({
      type: 'card_generated',
      card: card,
    }));
  }
}

async function handleCardOffered(ws: WebSocket, event: CardEvent): Promise<void> {
  const card = await getCard(event.card_id);
  const ownership = await getCardOwnership(event.card_id);
  
  if (card && ownership) {
    ws.send(JSON.stringify({
      type: 'card_offered',
      card: card,
      claim_deadline: ownership.claim_deadline,
    }));
  }
}

async function handleCardClaimed(ws: WebSocket, event: CardEvent): Promise<void> {
  const card = await getCard(event.card_id);
  if (card) {
    ws.send(JSON.stringify({
      type: 'card_claimed',
      card_id: event.card_id,
      message: 'Card has been claimed',
    }));
  }
}

async function handleCardDeclined(ws: WebSocket, event: CardEvent): Promise<void> {
  ws.send(JSON.stringify({
    type: 'card_declined',
    card_id: event.card_id,
    message: 'Card declined',
  }));
}

async function handleCardExpired(ws: WebSocket, event: CardEvent): Promise<void> {
  ws.send(JSON.stringify({
    type: 'card_expired',
    card_id: event.card_id,
    message: 'Claim deadline expired',
  }));
}

/**
 * Broadcast card event to conversation participants
 */
export async function broadcastCardEvent(
  conversationId: string,
  event: CardEvent
): Promise<void> {
  // TODO: Integrate with WebSocket room system
  // This should broadcast to all participants in the conversation
  // For now, placeholder
}
