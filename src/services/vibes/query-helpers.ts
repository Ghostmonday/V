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

