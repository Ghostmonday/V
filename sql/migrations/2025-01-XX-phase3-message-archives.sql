-- ===============================================
-- Migration: Phase 3 - Message Archives Table
-- Purpose: Create message_archives table for cold storage
-- Date: 2025-01-XX
-- Phase: 3.3 Message Archival
-- ===============================================

BEGIN;

-- ===============================================
-- MESSAGE ARCHIVES TABLE
-- ===============================================
-- Stores archived messages in encrypted format
-- Messages older than 90 days are moved here for cold storage

CREATE TABLE IF NOT EXISTS message_archives (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL UNIQUE REFERENCES messages(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  archived_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  archive_format TEXT NOT NULL DEFAULT 'encrypted_json_v1',
  archive_checksum TEXT NOT NULL, -- SHA256 checksum for integrity verification
  archive_data TEXT NOT NULL, -- Encrypted JSON data (in production, this would be a URI to S3/cloud storage)
  cold_storage_uri TEXT, -- Optional URI to external cold storage (S3, Glacier, etc.)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for efficient archive queries
CREATE INDEX IF NOT EXISTS idx_message_archives_message_id 
ON message_archives(message_id);

CREATE INDEX IF NOT EXISTS idx_message_archives_room_id 
ON message_archives(room_id);

CREATE INDEX IF NOT EXISTS idx_message_archives_archived_at 
ON message_archives(archived_at DESC);

-- Composite index for room-specific archive queries
CREATE INDEX IF NOT EXISTS idx_message_archives_room_archived 
ON message_archives(room_id, archived_at DESC);

COMMIT;

-- ===============================================
-- VERIFICATION QUERY
-- ===============================================
-- Run this to verify table was created:
-- SELECT 
--   table_name,
--   column_name,
--   data_type,
--   is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'message_archives'
-- ORDER BY ordinal_position;

