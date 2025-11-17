-- ===============================================
-- Phase 8: Deleted Users Table
-- Purpose: Track soft-deleted users with retention period
-- ===============================================

BEGIN;

-- Create deleted_users table for tracking soft-deleted accounts
CREATE TABLE IF NOT EXISTS deleted_users (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  retention_until TIMESTAMPTZ NOT NULL, -- When data can be permanently deleted
  anonymized_at TIMESTAMPTZ, -- When PII was anonymized
  deletion_reason TEXT, -- 'user_request', 'admin_action', 'compliance', etc.
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for finding users ready for permanent deletion
CREATE INDEX IF NOT EXISTS idx_deleted_users_retention ON deleted_users(retention_until) 
  WHERE anonymized_at IS NULL;

-- Index for finding users ready for anonymization
CREATE INDEX IF NOT EXISTS idx_deleted_users_anonymization ON deleted_users(deleted_at) 
  WHERE anonymized_at IS NULL;

-- RLS policies (only service role can access)
ALTER TABLE deleted_users ENABLE ROW LEVEL SECURITY;

-- No public access (service role only via service schema)
CREATE POLICY deleted_users_no_public ON deleted_users
  FOR ALL
  USING (false);

COMMIT;

-- ===============================================
-- Validation
-- ===============================================
-- SELECT table_name FROM information_schema.tables WHERE table_name = 'deleted_users';

