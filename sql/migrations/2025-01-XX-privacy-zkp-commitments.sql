-- ===============================================
-- Migration: Zero-Knowledge Proof Commitments
-- Purpose: Store ZKP commitments for selective disclosure
-- ===============================================

BEGIN;

-- Create user_zkp_commitments table for storing proof commitments
CREATE TABLE IF NOT EXISTS user_zkp_commitments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  attribute_type TEXT NOT NULL CHECK (attribute_type IN ('age', 'verified', 'subscription_tier', 'location_country', 'custom')),
  commitment TEXT NOT NULL, -- Hash commitment (public, doesn't reveal value)
  proof_data JSONB DEFAULT '{}'::jsonb, -- Optional: encrypted proof data
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ, -- Optional expiration
  revoked_at TIMESTAMPTZ -- If proof was revoked
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_zkp_commitments_user_id ON user_zkp_commitments(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_zkp_commitments_type ON user_zkp_commitments(attribute_type, commitment);
CREATE INDEX IF NOT EXISTS idx_zkp_commitments_active ON user_zkp_commitments(user_id, attribute_type) 
  WHERE revoked_at IS NULL AND (expires_at IS NULL OR expires_at > now());

-- RLS policies
ALTER TABLE user_zkp_commitments ENABLE ROW LEVEL SECURITY;

-- Users can view their own commitments
CREATE POLICY zkp_commitments_select_own ON user_zkp_commitments
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own commitments
CREATE POLICY zkp_commitments_insert_own ON user_zkp_commitments
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own commitments (for revocation)
CREATE POLICY zkp_commitments_update_own ON user_zkp_commitments
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

COMMIT;

-- ===============================================
-- Validation
-- ===============================================
-- SELECT table_name FROM information_schema.tables WHERE table_name = 'user_zkp_commitments';
-- SELECT * FROM user_zkp_commitments LIMIT 1;

