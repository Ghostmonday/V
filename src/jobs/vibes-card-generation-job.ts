/**
 * VIBES Card Generation Job
 * Background job that checks conversations and generates cards
 */

import { supabase } from '../config/db.ts';
import { logInfo, logError } from '../shared/logger.js';
import { qualifiesForCardGeneration } from '../services/vibes/conversation-service.js';
import { getSentimentAnalysis, analyzeConversation } from '../services/vibes/sentiment-service.js';
import { calculateRarity } from '../services/vibes/rarity-engine.js';
import { generateCard } from '../services/vibes/card-generator.js';
import { offerCard, defaultToFounderVault } from '../services/vibes/ownership-service.js';
import { vibesConfig } from '../config/vibes.config.js';

/**
 * Process conversations that qualify for card generation
 */
export async function processCardGeneration(): Promise<void> {
  if (!vibesConfig.cardGenerationEnabled) {
    return;
  }

  try {
    // Find conversations that qualify but haven't been analyzed
    const { data: conversations, error } = await supabase
      .from('conversations')
      .select('id, message_count')
      .gte('message_count', 5) // Minimum messages
      .order('updated_at', { ascending: false })
      .limit(10);

    if (error) throw error;

    for (const conversation of conversations || []) {
      try {
        // Check if already has card
        const { data: existingCard } = await supabase
          .from('cards')
          .select('id')
          .eq('conversation_id', conversation.id)
          .single();

        if (existingCard) {
          continue; // Already has card
        }

        // Check if qualifies
        const qualifies = await qualifiesForCardGeneration(conversation.id);
        if (!qualifies) {
          continue;
        }

        // Get messages for analysis
        const { data: messages } = await supabase
          .from('messages')
          .select('content, sender_id, created_at')
          .eq('conversation_id', conversation.id)
          .order('created_at', { ascending: true });

        if (!messages || messages.length < 5) {
          continue;
        }

        // Analyze sentiment
        const sentiment = await analyzeConversation(conversation.id, messages);

        // Check safety flags
        if (sentiment.safety_flags.length > 0) {
          logInfo('Skipping card generation due to safety flags', {
            conversation_id: conversation.id,
            flags: sentiment.safety_flags,
          });
          continue;
        }

        // Get participants for rarity calculation
        const { data: participants } = await supabase
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', conversation.id);

        // Calculate rarity
        const rarity = calculateRarity(
          sentiment,
          participants || [],
          messages.map((m) => ({ type: m.message_type || 'text' })),
          undefined // TODO: Add participant metadata
        );

        // Generate card
        const card = await generateCard(conversation as any, sentiment, rarity);

        // Offer to participants
        const participantIds = (participants || []).map((p) => p.user_id);
        await offerCard(card, participantIds);

        logInfo('Card generated successfully', {
          card_id: card.id,
          conversation_id: conversation.id,
          rarity: rarity.final_tier,
        });
      } catch (error) {
        logError('Failed to process conversation for card generation', error);
        // Continue with next conversation
      }
    }
  } catch (error) {
    logError('Card generation job failed', error);
  }
}

/**
 * Process expired card claims (default to founder vault)
 */
export async function processExpiredClaims(): Promise<void> {
  try {
    const { data: expiredClaims, error } = await supabase
      .from('card_ownerships')
      .select('card_id, claim_deadline')
      .not('claim_deadline', 'is', null)
      .lt('claim_deadline', new Date().toISOString())
      .eq('acquisition_type', 'claimed');

    if (error) throw error;

    for (const claim of expiredClaims || []) {
      // Check if anyone actually claimed it
      const { data: actualOwners } = await supabase
        .from('card_ownerships')
        .select('owner_id')
        .eq('card_id', claim.card_id)
        .neq('acquisition_type', 'claimed');

      // If no one claimed, default to founder vault
      if (!actualOwners || actualOwners.length === 0) {
        await defaultToFounderVault(claim.card_id);
      }
    }
  } catch (error) {
    logError('Failed to process expired claims', error);
  }
}
