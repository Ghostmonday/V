-- ===============================================
-- FILE: 15_analyze_tables.sql
-- PURPOSE: Update table statistics for optimal query planning
-- USAGE: Run periodically (weekly/monthly) to keep stats fresh
-- Run after adding indexes or bulk data changes
-- ===============================================

-- Analyze all tables to update statistics for query planner
-- This helps PostgreSQL choose optimal query plans

ANALYZE users;
ANALYZE rooms;
ANALYZE room_memberships;
ANALYZE messages;
ANALYZE message_receipts;
ANALYZE audit_log;
ANALYZE logs_raw;
ANALYZE logs_compressed;
ANALYZE retention_schedule;
ANALYZE legal_holds;
ANALYZE telemetry;
ANALYZE threads;
ANALYZE edit_history;
ANALYZE assistants;
ANALYZE bots;
ANALYZE bot_endpoints;
ANALYZE subscriptions;
ANALYZE embeddings;
ANALYZE metrics;
ANALYZE presence_logs;
ANALYZE healing_logs;

-- Show table statistics after analysis
SELECT 
  schemaname,
  tablename,
  n_live_tup AS row_count,
  n_dead_tup AS dead_rows,
  CASE 
    WHEN n_live_tup > 0 THEN ROUND(100.0 * n_dead_tup / n_live_tup, 2)
    ELSE 0
  END AS dead_row_percentage,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze,
  CASE 
    WHEN last_analyze IS NULL AND last_autoanalyze IS NULL THEN 'NEVER'
    WHEN last_analyze > last_autoanalyze THEN last_analyze::TEXT
    ELSE last_autoanalyze::TEXT
  END AS last_analysis
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;

-- Show index statistics
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan AS index_scans,
  idx_tup_read AS tuples_read,
  idx_tup_fetch AS tuples_fetched,
  CASE 
    WHEN idx_scan = 0 THEN 'UNUSED'
    WHEN idx_scan < 100 THEN 'LOW'
    WHEN idx_scan < 1000 THEN 'MEDIUM'
    ELSE 'HIGH'
  END AS usage_level
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY idx_scan DESC;

