/**
 * Type definitions for messages, reactions, threads, and voice
 */

export interface Message {
  id: string;
  room_id: string;
  sender_id: string;
  content_preview: string;
  content?: string;
  created_at: string;
  updated_at?: string;
  thread_id?: string;
  reply_to?: string;
  reactions?: MessageReaction[];
  is_edited?: boolean;
  is_flagged?: boolean;
  user?: {
    username?: string;
    avatar_url?: string;
  };
}

export interface MessageReaction {
  emoji: string;
  user_ids: string[];
  count: number;
}

export interface Thread {
  id: string;
  parent_message_id: string;
  room_id: string;
  title?: string;
  created_at: string;
  updated_at: string;
  message_count: number;
  is_archived: boolean;
  created_by?: string;
  parent_message?: Message;
  recent_messages?: Message[];
}

export interface CreateThreadRequest {
  parent_message_id: string;
  title?: string;
  initial_message?: string;
}

export interface ReactionUpdate {
  message_id: string;
  reaction: MessageReaction;
  action: 'add' | 'remove';
  user_id: string;
}

export interface EditHistory {
  id: string;
  message_id: string;
  old_content: string;
  edited_by: string;
  edited_at: string;
}

// Voice/Video types
export interface VoiceSession {
  room_name: string;
  participant_count: number;
  participants: VoiceParticipant[];
}

export interface VoiceParticipant {
  id: string;
  user_id: string;
  identity: string;
  is_speaking: boolean;
  audio_level: number;
  connection_quality: number;
}

export interface VoiceStats {
  latency: number;
  packet_loss: number;
  jitter: number;
  bitrate: number;
}

