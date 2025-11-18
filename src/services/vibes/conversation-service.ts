/**
 * VIBES Conversation Service
 * Handles conversation creation, joining, and lifecycle
 */

import { supabase } from '../../config/db.ts';
import { logError } from '../../shared/logger.js';
import { ConversationNotFoundError, handleVIBESError } from './error-handler.js';
import { VIBES_CONSTANTS } from './constants.js';

export interface Conversation {
  id: string;
  created_by: string | null;
  created_at: Date;
  updated_at: Date;
  last_message_at: Date | null;
  message_count: number;
  is_group: boolean;
  metadata: Record<string, any>;
}

export interface ConversationParticipant {
  id: string;
  conversation_id: string;
  user_id: string;
  joined_at: Date;
  last_read_at: Date | null;
}

/**
 * Create a new conversation
 */
export async function createConversation(
  createdBy: string,
  participantIds: string[],
  isGroup: boolean = false
): Promise<Conversation> {
  try {
    // Create conversation
    const { data: conversation, error: convError } = await supabase
      .from('conversations')
      .insert({
        created_by: createdBy,
        is_group: isGroup,
        message_count: 0,
      })
      .select()
      .single();

    if (convError) throw convError;

    // Add participants
    const participants = participantIds.map((userId) => ({
      conversation_id: conversation.id,
      user_id: userId,
    }));

    const { error: partError } = await supabase
      .from('conversation_participants')
      .insert(participants);

    if (partError) throw partError;

    return conversation as Conversation;
  } catch (error) {
    logError('Failed to create conversation', error);
    throw error;
  }
}

/**
 * Get conversation by ID
 */
export async function getConversation(conversationId: string): Promise<Conversation> {
  try {
    const { data, error } = await supabase
      .from('conversations')
      .select('*')
      .eq('id', conversationId)
      .single();

    if (error) throw error;
    if (!data) throw new ConversationNotFoundError(conversationId);
    return data as Conversation;
  } catch (error) {
    throw handleVIBESError(error);
  }
}

/**
 * Get user's conversations
 */
export async function getUserConversations(userId: string): Promise<Conversation[]> {
  try {
    const { data, error } = await supabase
      .from('conversation_participants')
      .select(
        `
        conversation_id,
        conversations (*)
      `
      )
      .eq('user_id', userId)
      .order('joined_at', { ascending: false });

    if (error) throw error;

    return (data || []).map((item: any) => item.conversations).filter(Boolean);
  } catch (error) {
    logError('Failed to get user conversations', error);
    return [];
  }
}

/**
 * Add participant to conversation
 */
export async function addParticipant(conversationId: string, userId: string): Promise<void> {
  try {
    const { error } = await supabase.from('conversation_participants').insert({
      conversation_id: conversationId,
      user_id: userId,
    });

    if (error) throw error;
  } catch (error) {
    logError('Failed to add participant', error);
    throw error;
  }
}
