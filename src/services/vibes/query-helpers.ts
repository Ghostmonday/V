/**
 * VIBES Query Helpers
 * Optimized database queries for VIBES
 */

import { supabase } from '../../config/db.ts';

/**
 * Get conversation with participant count
 */
export async function getConversationWithStats(conversationId: string) {
  const { data: conversation, error: convError } = await supabase
    .from('conversations')
    .select('*')
    .eq('id', conversationId)
    .single();

  if (convError || !conversation) {
    return null;
  }

  // Get participant count
  const { count } = await supabase
    .from('conversation_participants')
    .select('*', { count: 'exact', head: true })
    .eq('conversation_id', conversationId);

  return {
    ...conversation,
    participant_count: count || 0,
  };
}

/**
 * Get cards with ownership info (for museum)
 */
export async function getCardsWithOwnership(cardIds: string[]) {
  const { data: cards, error } = await supabase
    .from('cards')
    .select(`
      *,
      card_ownerships!inner (
        owner_id,
        acquisition_type,
        acquired_at
      )
    `)
    .in('id', cardIds);

  if (error) throw error;
  return cards || [];
}

/**
 * Get user's card count by rarity
 */
export async function getUserCardStats(userId: string) {
  const { data, error } = await supabase
    .from('card_ownerships')
    .select(`
      card_id,
      cards!inner (frame_style)
    `)
    .eq('owner_id', userId);

  if (error) throw error;

  const stats = {
    total: data?.length || 0,
    by_rarity: {
      common: 0,
      uncommon: 0,
      rare: 0,
      epic: 0,
      legendary: 0,
    },
  };

  (data || []).forEach((item: any) => {
    const rarity = item.cards?.frame_style;
    if (rarity && stats.by_rarity[rarity as keyof typeof stats.by_rarity] !== undefined) {
      stats.by_rarity[rarity as keyof typeof stats.by_rarity]++;
    }
  });

  return stats;
}
