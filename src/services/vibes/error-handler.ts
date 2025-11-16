/**
 * VIBES Error Handler
 * Standardized error handling for VIBES services
 */

import { logError } from '../../shared/logger.js';

export class VIBESError extends Error {
  constructor(
    public code: string,
    message: string,
    public statusCode: number = 500,
    public details?: any
  ) {
    super(message);
    this.name = 'VIBESError';
  }
}

export class CardNotFoundError extends VIBESError {
  constructor(cardId: string) {
    super('CARD_NOT_FOUND', `Card not found: ${cardId}`, 404, { cardId });
  }
}

export class ConversationNotFoundError extends VIBESError {
  constructor(conversationId: string) {
    super('CONVERSATION_NOT_FOUND', `Conversation not found: ${conversationId}`, 404, { conversationId });
  }
}

export class CardAlreadyClaimedError extends VIBESError {
  constructor(cardId: string) {
    super('CARD_ALREADY_CLAIMED', `Card already claimed: ${cardId}`, 409, { cardId });
  }
}

export class ClaimExpiredError extends VIBESError {
  constructor(cardId: string) {
    super('CLAIM_EXPIRED', `Claim deadline expired for card: ${cardId}`, 410, { cardId });
  }
}

export class SafetyFlagError extends VIBESError {
  constructor(flags: string[]) {
    super('SAFETY_FLAGS', 'Card generation blocked due to safety flags', 403, { flags });
  }
}

/**
 * Handle VIBES errors and log appropriately
 */
export function handleVIBESError(error: unknown): VIBESError {
  if (error instanceof VIBESError) {
    logError(`VIBES Error [${error.code}]: ${error.message}`, error);
    return error;
  }

  // Unknown error - wrap it
  const vibesError = new VIBESError(
    'INTERNAL_ERROR',
    error instanceof Error ? error.message : 'Unknown error',
    500,
    error
  );
  
  logError('Unhandled VIBES error', error);
  return vibesError;
}
