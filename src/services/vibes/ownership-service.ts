/**
 * VIBES Ownership Service
 * Handles card ownership, claims, and transfers
 */

import { supabase } from '../../config/db.ts';
import { logError } from '../../shared/logger.js';
import { vibesConfig } from '../../config/vibes.config.js';
import { Card } from './card-generator.js';

export interface CardOwnership {
  id: string;
  card_id: string;
  owner_id: string;
  acquired_at: Date;
  acquisition_type: 'claimed' | 'defaulted' | 'purchased';
  claim_deadline: Date | null;
  previous_owner_id: string | null;
}

/**
 * Offer card to participants with claim deadline
 */
export async function offerCard(
  card: Card,
  participantIds: string[]
): Promise<void> {
  try {
    const deadline = new Date();
    deadline.setMinutes(deadline.getMinutes() + vibesConfig.claimDeadlineMinutes);

    // Create ownership entries for each participant (pending claim)
    const ownerships = participantIds.map(userId => ({
      card_id: card.id,
      owner_id: userId,
      acquisition_type: 'claimed' as const,
      claim_deadline: deadline,
    }));

    // Note: We'll handle the actual claim logic separately
    // This just sets up the offer structure
    
    // Create event
    await supabase
      .from('card_events')
      .insert({
        card_id: card.id,
        event_type: 'offered',
        metadata: {
          participant_count: participantIds.length,
          deadline: deadline.toISOString(),
        },
      });
  } catch (error) {
    logError('Failed to offer card', error);
    throw error;
  }
}

/**
 * Claim a card (user accepts)
 */
export async function claimCard(
  cardId: string,
  userId: string
): Promise<CardOwnership> {
  try {
    // Check if user is eligible
    const { data: existing, error: checkError } = await supabase
      .from('card_ownerships')
      .select('*')
      .eq('card_id', cardId)
      .eq('owner_id', userId)
      .single();

    if (checkError && checkError.code !== 'PGRST116') throw checkError;

    if (existing) {
      // Already claimed
      return existing as CardOwnership;
    }

    // Create ownership
    const { data, error } = await supabase
      .from('card_ownerships')
      .insert({
        card_id: cardId,
        owner_id: userId,
        acquisition_type: 'claimed',
      })
      .select()
      .single();

    if (error) throw error;

    // Create event
    await supabase
      .from('card_events')
      .insert({
        card_id: cardId,
        event_type: 'claimed',
        user_id: userId,
      });

    return data as CardOwnership;
  } catch (error) {
    logError('Failed to claim card', error);
    throw error;
  }
}

/**
 * Decline card (user rejects)
 */
export async function declineCard(
  cardId: string,
  userId: string
): Promise<void> {
  try {
    // Remove ownership entry if exists
    await supabase
      .from('card_ownerships')
      .delete()
      .eq('card_id', cardId)
      .eq('owner_id', userId);

    // Create event
    await supabase
      .from('card_events')
      .insert({
        card_id: cardId,
        event_type: 'declined',
        user_id: userId,
      });
  } catch (error) {
    logError('Failed to decline card', error);
    throw error;
  }
}

/**
 * Default card to founder vault (timeout or all declined)
 */
export async function defaultToFounderVault(cardId: string): Promise<void> {
  try {
    if (!vibesConfig.founderVaultAddress) {
      logError('Founder vault address not configured', new Error('Missing FOUNDER_VAULT_ADDRESS'));
      return;
    }

    // Create ownership for founder vault
    // Note: Using a special user ID for founder vault
    const founderUserId = vibesConfig.founderVaultAddress; // Or map to actual user ID

    const { error } = await supabase
      .from('card_ownerships')
      .insert({
        card_id: cardId,
        owner_id: founderUserId,
        acquisition_type: 'defaulted',
      });

    if (error) throw error;

    // Create event
    await supabase
      .from('card_events')
      .insert({
        card_id: cardId,
        event_type: 'defaulted',
        metadata: { reason: 'claim_timeout' },
      });
  } catch (error) {
    logError('Failed to default card to founder vault', error);
    throw error;
  }
}

/**
 * Get user's owned cards
 */
export async function getUserCards(userId: string): Promise<Card[]> {
  try {
    const { data, error } = await supabase
      .from('card_ownerships')
      .select(`
        card_id,
        cards (*)
      `)
      .eq('owner_id', userId)
      .order('acquired_at', { ascending: false });

    if (error) throw error;

    return (data || []).map((item: any) => item.cards).filter(Boolean);
  } catch (error) {
    logError('Failed to get user cards', error);
    return [];
  }
}

/**
 * Get card ownership
 */
export async function getCardOwnership(cardId: string): Promise<CardOwnership | null> {
  try {
    const { data, error } = await supabase
      .from('card_ownerships')
      .select('*')
      .eq('card_id', cardId)
      .single();

    if (error) throw error;
    return data as CardOwnership | null;
  } catch (error) {
    logError('Failed to get card ownership', error);
    return null;
  }
}
