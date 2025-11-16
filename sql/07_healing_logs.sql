-- ===============================================
-- FILE: 07_healing_logs.sql
-- PURPOSE: Healing logs table for autonomy system error tracking
-- DESCRIPTION: Tracks failures and errors from the autonomy healing loop
-- ===============================================

-- Healing logs: Tracks failures and errors from autonomy system
CREATE TABLE IF NOT EXISTS healing_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL, -- 'loop_failure', 'llm_parse_error', 'validation_error', etc.
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  details TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_healing_logs_timestamp ON healing_logs (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_healing_logs_room_id ON healing_logs (room_id) WHERE room_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_healing_logs_type ON healing_logs (type);

