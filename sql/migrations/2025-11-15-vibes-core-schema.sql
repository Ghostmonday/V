-- ===============================================
-- VIBES Core Database Schema
-- Purpose: Foundation tables for conversation-to-card system
-- Date: 2025-11-15
-- ===============================================

BEGIN;

-- ===============================================
-- 1. CONVERSATIONS (renamed from rooms)
-- ===============================================
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_message_at TIMESTAMPTZ,
  message_count INTEGER DEFAULT 0,
  is_group BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- ===============================================
-- 2. CONVERSATION PARTICIPANTS (renamed from room_memberships)
-- ===============================================
CREATE TABLE IF NOT EXISTS conversation_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_read_at TIMESTAMPTZ,
  UNIQUE(conversation_id, user_id)
);

-- ===============================================
-- 3. MESSAGES (enhanced for VIBES)
-- ===============================================
-- Note: messages table already exists, we'll add VIBES-specific fields
ALTER TABLE messages 
  ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'voice', 'image')),
  ADD COLUMN IF NOT EXISTS voice_url TEXT,
  -- sentiment_score removed (gamification element)
  ADD COLUMN IF NOT EXISTS is_analyzed BOOLEAN DEFAULT false;

-- Create index for conversation lookups
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id, created_at DESC);

-- ===============================================
-- 4. SENTIMENT ANALYSIS (cache for card generation)
-- ===============================================
CREATE TABLE IF NOT EXISTS sentiment_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  analysis_data JSONB NOT NULL,
  -- sentiment_score and emotional_intensity removed (gamification elements)
  surprise_factor NUMERIC NOT NULL,
  keywords TEXT[],
  breakup_detected BOOLEAN DEFAULT false,
  -- safety_flags removed (gamification element)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(conversation_id)
);

CREATE INDEX IF NOT EXISTS idx_sentiment_conversation ON sentiment_analysis(conversation_id);
-- idx_sentiment_score removed (sentiment_score column removed)

-- ===============================================
-- 5. CARDS (the collectibles)
-- ===============================================
CREATE TABLE IF NOT EXISTS cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sentiment_analysis_id UUID REFERENCES sentiment_analysis(id) ON DELETE SET NULL,
  artwork_url TEXT NOT NULL,
  frame_style TEXT NOT NULL CHECK (frame_style IN ('common', 'uncommon', 'rare', 'epic', 'legendary')),
  title TEXT NOT NULL,
  caption TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  rarity_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  ipfs_cid TEXT,
  arweave_txid TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  generated_at TIMESTAMPTZ,
  is_burned BOOLEAN DEFAULT false,
  burned_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_cards_conversation ON cards(conversation_id);
CREATE INDEX IF NOT EXISTS idx_cards_frame_style ON cards(frame_style);
CREATE INDEX IF NOT EXISTS idx_cards_created ON cards(created_at DESC);

-- ===============================================
-- 6. CARD OWNERSHIPS (who owns what)
-- ===============================================
CREATE TABLE IF NOT EXISTS card_ownerships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  acquired_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  acquisition_type TEXT NOT NULL CHECK (acquisition_type IN ('claimed', 'defaulted', 'purchased')),
  claim_deadline TIMESTAMPTZ,
  previous_owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE(card_id, owner_id)
);

CREATE INDEX IF NOT EXISTS idx_ownership_owner ON card_ownerships(owner_id, acquired_at DESC);
CREATE INDEX IF NOT EXISTS idx_ownership_card ON card_ownerships(card_id);

-- ===============================================
-- 7. CARD EVENTS (audit trail)
-- ===============================================
CREATE TABLE IF NOT EXISTS card_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('generated', 'offered', 'claimed', 'declined', 'defaulted', 'burned', 'printed')),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_events_card ON card_events(card_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_type ON card_events(event_type);

-- ===============================================
-- 8. MUSEUM ENTRIES (public visibility)
-- ===============================================
CREATE TABLE IF NOT EXISTS museum_entries (
  card_id UUID PRIMARY KEY REFERENCES cards(id) ON DELETE CASCADE,
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public', 'redacted', 'burned', 'private')),
  view_count INTEGER DEFAULT 0,
  featured BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_museum_visibility ON museum_entries(visibility, view_count DESC);
CREATE INDEX IF NOT EXISTS idx_museum_featured ON museum_entries(featured) WHERE featured = true;

-- ===============================================
-- 9. BOOSTS / TRANSACTIONS (monetization)
-- ===============================================
CREATE TABLE IF NOT EXISTS boosts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  boost_type TEXT NOT NULL CHECK (boost_type IN ('rarity_boost')), -- Gamification removed: scream_multiplier, print_order
  amount_paid NUMERIC NOT NULL,
  payment_provider TEXT,
  payment_id TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_boosts_user ON boosts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_boosts_conversation ON boosts(conversation_id);

COMMIT;

-- ===============================================
-- Validation Queries
-- ===============================================
-- Run these to verify schema:
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('conversations', 'conversation_participants', 'sentiment_analysis', 'cards', 'card_ownerships', 'card_events', 'museum_entries', 'boosts');
