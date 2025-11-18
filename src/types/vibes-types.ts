/**
 * VIBES Type Definitions
 * Centralized types for VIBES system
 */

// Conversation Types
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

// Sentiment Types (gamification removed)
export interface SentimentAnalysis {
  id: string;
  conversation_id: string;
  surprise_factor: number; // 0 to 1
  keywords: string[];
  breakup_detected: boolean;
  analysis_data: Record<string, any>;
  created_at: Date;
}

// Boost Types (gamification removed - no boost types)
export type BoostType = never;

export interface Boost {
  id: string;
  conversation_id: string | null;
  user_id: string;
  boost_type: BoostType;
  amount_paid: number;
  payment_provider: string | null;
  payment_id: string | null;
  metadata: Record<string, any>;
  created_at: Date;
}
