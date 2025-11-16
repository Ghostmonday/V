/**
 * VIBES Museum Service
 * Public ledger of all cards
 */

import { supabase } from '../../config/db.ts';
import { logError } from '../../shared/logger.js';
import { Card } from './card-generator.js';

export interface MuseumEntry {
  card: Card;
  owner_id: string | null;
  visibility: 'public' | 'redacted' | 'burned' | 'private';
  view_count: number;
  featured: boolean;
}

export interface MuseumFilters {
  rarity?: string;
  featured?: boolean;
  limit?: number;
  offset?: number;
}

/**
 * Get public museum entries
 */
export async function getPublicCards(filters: MuseumFilters = {}): Promise<MuseumEntry[]> {
  try {
    let query = supabase
      .from('museum_entries')
      .select(`
        *,
        cards (*),
        card_ownerships!inner (owner_id)
      `)
      .eq('visibility', 'public')
      .order('view_count', { ascending: false });

    if (filters.rarity) {
      query = query.eq('cards.frame_style', filters.rarity);
    }

    if (filters.featured) {
      query = query.eq('featured', true);
    }

    if (filters.limit) {
      query = query.limit(filters.limit);
    }

    if (filters.offset) {
      query = query.range(filters.offset, filters.offset + (filters.limit || 20) - 1);
    }

    const { data, error } = await query;

    if (error) throw error;

    return (data || []).map((item: any) => ({
      card: item.cards,
      owner_id: item.card_ownerships?.[0]?.owner_id || null,
      visibility: item.visibility,
      view_count: item.view_count,
      featured: item.featured,
    }));
  } catch (error) {
    logError('Failed to get public cards', error);
    return [];
  }
}

/**
 * Increment view count for card
 */
export async function incrementViewCount(cardId: string): Promise<void> {
  try {
    await supabase.rpc('increment_museum_views', { card_id: cardId });
  } catch (error) {
    // Fallback if RPC doesn't exist
    const { data } = await supabase
      .from('museum_entries')
      .select('view_count')
      .eq('card_id', cardId)
      .single();

    if (data) {
      await supabase
        .from('museum_entries')
        .update({ view_count: (data.view_count || 0) + 1 })
        .eq('card_id', cardId);
    }
  }
}

/**
 * Get redacted entries (for admin)
 */
export async function getRedactedCards(): Promise<MuseumEntry[]> {
  try {
    const { data, error } = await supabase
      .from('museum_entries')
      .select(`
        *,
        cards (*)
      `)
      .in('visibility', ['redacted', 'burned'])
      .order('updated_at', { ascending: false });

    if (error) throw error;

    return (data || []).map((item: any) => ({
      card: item.cards,
      owner_id: null, // Redacted
      visibility: item.visibility,
      view_count: item.view_count,
      featured: false,
    }));
  } catch (error) {
    logError('Failed to get redacted cards', error);
    return [];
  }
}
