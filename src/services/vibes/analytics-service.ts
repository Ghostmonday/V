/**
 * VIBES Analytics Service
 * Track metrics for $5K/month goal
 */

import { supabase } from '../../config/db.ts';
import { logError } from '../../shared/logger.js';

export interface VIBESAnalytics {
  total_cards: number;
  cards_today: number;
  cards_this_week: number;
  claims_pending: number;
  claims_completed: number;
  by_rarity: Record<string, number>;
  top_creators: Array<{ user_id: string; card_count: number }>;
}

/**
 * Get VIBES analytics
 */
export async function getVIBESAnalytics(): Promise<VIBESAnalytics> {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const weekAgo = new Date(today);
    weekAgo.setDate(weekAgo.getDate() - 7);

    // Total cards
    const { count: totalCards } = await supabase
      .from('cards')
      .select('*', { count: 'exact', head: true });

    // Cards today
    const { count: cardsToday } = await supabase
      .from('cards')
      .select('*', { count: 'exact', head: true })
      .gte('created_at', today.toISOString());

    // Cards this week
    const { count: cardsThisWeek } = await supabase
      .from('cards')
      .select('*', { count: 'exact', head: true })
      .gte('created_at', weekAgo.toISOString());

    // Pending claims
    const { count: claimsPending } = await supabase
      .from('card_ownerships')
      .select('*', { count: 'exact', head: true })
      .not('claim_deadline', 'is', null)
      .gt('claim_deadline', new Date().toISOString());

    // Completed claims
    const { count: claimsCompleted } = await supabase
      .from('card_ownerships')
      .select('*', { count: 'exact', head: true })
      .eq('acquisition_type', 'claimed');

    // By rarity
    const { data: rarityData } = await supabase
      .from('cards')
      .select('frame_style');

    const byRarity: Record<string, number> = {
      common: 0,
      uncommon: 0,
      rare: 0,
      epic: 0,
      legendary: 0,
    };

    (rarityData || []).forEach((card: any) => {
      const rarity = card.frame_style;
      if (rarity && byRarity[rarity]) {
        byRarity[rarity]++;
      }
    });

    // Top creators (by conversation creation)
    const { data: creators } = await supabase
      .from('conversations')
      .select('created_by')
      .not('created_by', 'is', null);

    const creatorCounts: Record<string, number> = {};
    (creators || []).forEach((conv: any) => {
      if (conv.created_by) {
        creatorCounts[conv.created_by] = (creatorCounts[conv.created_by] || 0) + 1;
      }
    });

    const topCreators = Object.entries(creatorCounts)
      .map(([user_id, card_count]) => ({ user_id, card_count }))
      .sort((a, b) => b.card_count - a.card_count)
      .slice(0, 10);

    return {
      total_cards: totalCards || 0,
      cards_today: cardsToday || 0,
      cards_this_week: cardsThisWeek || 0,
      claims_pending: claimsPending || 0,
      claims_completed: claimsCompleted || 0,
      by_rarity: byRarity,
      top_creators: topCreators,
    };
  } catch (error) {
    logError('Failed to get VIBES analytics', error);
    throw error;
  }
}

/**
 * Track card generation event
 */
export async function trackCardGeneration(cardId: string, rarity: string): Promise<void> {
  try {
    await supabase
      .from('card_events')
      .insert({
        card_id: cardId,
        event_type: 'generated',
        metadata: { rarity },
      });
  } catch (error) {
    // Silent fail - analytics shouldn't block operations
    logError('Failed to track card generation', error);
  }
}

/**
 * Track card claim event
 */
export async function trackCardClaim(cardId: string, userId: string): Promise<void> {
  try {
    await supabase
      .from('card_events')
      .insert({
        card_id: cardId,
        event_type: 'claimed',
        user_id: userId,
      });
  } catch (error) {
    logError('Failed to track card claim', error);
  }
}
