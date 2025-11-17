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

// Sentiment Types
export interface SentimentAnalysis {
  id: string;
  conversation_id: string;
  sentiment_score: number; // -1 to 1
  emotional_intensity: number; // 0 to 1
  surprise_factor: number; // 0 to 1
  keywords: string[];
  breakup_detected: boolean;
  safety_flags: string[];
  analysis_data: Record<string, any>;
  created_at: Date;
}

// Rarity Types
export type RarityTier = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary';

export interface RarityCalculation {
  base_rarity: RarityTier;
  multipliers: {
    identity: number;
    dynamics: number;
    voice: number;
    group_size: number;
    surprise: number;
  };
  final_score: number;
  final_tier: RarityTier;
}

// Card Types
export interface Card {
  id: string;
  conversation_id: string;
  sentiment_analysis_id: string | null;
  artwork_url: string;
  frame_style: RarityTier;
  title: string;
  caption: string | null;
  metadata: Record<string, any>;
  rarity_data: Record<string, any>;
  created_at: Date;
  generated_at: Date | null;
  is_burned: boolean;
  burned_at: Date | null;
}

// Ownership Types
export type AcquisitionType = 'claimed' | 'defaulted' | 'purchased';

export interface CardOwnership {
  id: string;
  card_id: string;
  owner_id: string;
  acquired_at: Date;
  acquisition_type: AcquisitionType;
  claim_deadline: Date | null;
  previous_owner_id: string | null;
}

// Museum Types
export type MuseumVisibility = 'public' | 'redacted' | 'burned' | 'private';

export interface MuseumEntry {
  card: Card;
  owner_id: string | null;
  visibility: MuseumVisibility;
  view_count: number;
  featured: boolean;
}

export interface MuseumFilters {
  rarity?: RarityTier;
  featured?: boolean;
  limit?: number;
  offset?: number;
}

// Card Event Types
export interface CardEvent {
  type: 'card_generated' | 'card_offered' | 'card_claimed' | 'card_declined' | 'card_expired';
  card_id: string;
  conversation_id: string;
  data?: any;
}

// Boost Types
export type BoostType = 'scream_multiplier' | 'rarity_boost' | 'print_order';

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
