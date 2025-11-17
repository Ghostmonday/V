-- ===============================================
-- Migration: ZKP Commitments Index Optimization
-- Purpose: Optimize database queries for ZKP lookups with better indexing
-- ===============================================

BEGIN;

-- Add composite index for common query pattern: user_id + revoked_at + created_at
-- This optimizes: SELECT ... WHERE user_id = ? AND revoked_at IS NULL ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS idx_zkp_commitments_user_active_created 
  ON user_zkp_commitments(user_id, created_at DESC) 
  WHERE revoked_at IS NULL;

-- Add index for attribute type lookups (for verification queries)
CREATE INDEX IF NOT EXISTS idx_zkp_commitments_attribute_type 
  ON user_zkp_commitments(attribute_type, commitment);

-- Add index for expiration checks (for cleanup jobs)
CREATE INDEX IF NOT EXISTS idx_zkp_commitments_expires_at 
  ON user_zkp_commitments(expires_at) 
  WHERE expires_at IS NOT NULL;

-- Add partial index for active commitments by user (most common query)
-- This is more efficient than the full table scan
CREATE INDEX IF NOT EXISTS idx_zkp_commitments_user_active 
  ON user_zkp_commitments(user_id) 
  WHERE revoked_at IS NULL AND (expires_at IS NULL OR expires_at > now());

COMMIT;

-- ===============================================
-- Validation
-- ===============================================
-- SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'user_zkp_commitments';

