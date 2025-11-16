/**
 * VIBES Card Lifecycle Hook
 * Triggers card generation when conversations qualify
 */

import { logInfo } from '../../shared/logger.js';
import { qualifiesForCardGeneration } from './conversation-service.js';
import { getSentimentAnalysis } from './sentiment-service.js';
import { processCardGeneration } from '../../jobs/vibes-card-generation-job.js';

/**
 * Hook called after message is sent
 * Checks if conversation qualifies for card generation
 */
export async function onMessageSent(
  conversationId: string,
  messageId: string
): Promise<void> {
  try {
    // Check if already analyzed
    const existing = await getSentimentAnalysis(conversationId);
    if (existing) {
      return; // Already processed
    }

    // Check if qualifies
    const qualifies = await qualifiesForCardGeneration(conversationId);
    if (!qualifies) {
      return;
    }

    // Trigger card generation (async, don't block)
    processCardGeneration().catch(err => {
      logInfo('Card generation triggered but failed', { conversationId, error: err });
    });
  } catch (error) {
    // Don't block message sending if card generation check fails
    logInfo('Card lifecycle hook error', { conversationId, error });
  }
}
