-- ===============================================
-- Phase 8: Consent Records Table
-- Purpose: GDPR/CCPA consent management with audit trail
-- ===============================================

BEGIN;

-- Create consent_records table for tracking user consent
CREATE TABLE IF NOT EXISTS consent_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL CHECK (consent_type IN ('marketing', 'analytics', 'required', 'cookies', 'third_party')),
  granted BOOLEAN NOT NULL DEFAULT false,
  consent_version TEXT NOT NULL, -- Version of consent policy (e.g., '1.0', '2.1')
  ip_address TEXT,
  user_agent TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ, -- Optional expiration for time-limited consent
  withdrawn_at TIMESTAMPTZ -- When consent was withdrawn (if applicable)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_consent_records_user_id ON consent_records(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_consent_records_type ON consent_records(consent_type, granted);
CREATE INDEX IF NOT EXISTS idx_consent_records_active ON consent_records(user_id, consent_type, granted) 
  WHERE withdrawn_at IS NULL;

-- RLS policies
ALTER TABLE consent_records ENABLE ROW LEVEL SECURITY;

-- Users can view their own consent records
CREATE POLICY consent_records_select_own ON consent_records
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own consent records
CREATE POLICY consent_records_insert_own ON consent_records
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own consent records (for withdrawal)
CREATE POLICY consent_records_update_own ON consent_records
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

COMMIT;

-- ===============================================
-- Validation
-- ===============================================
-- SELECT table_name FROM information_schema.tables WHERE table_name = 'consent_records';
-- SELECT * FROM consent_records LIMIT 1;

