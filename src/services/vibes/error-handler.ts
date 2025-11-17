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

export class ConversationNotFoundError extends VIBESError {
  constructor(conversationId: string) {
    super('CONVERSATION_NOT_FOUND', `Conversation not found: ${conversationId}`, 404, { conversationId });
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
