-- ===============================================
-- FILE: 16_performance_tests.sql
-- PURPOSE: Test query performance and index usage
-- USAGE: Run after applying optimizations to verify improvements
-- ===============================================

-- ===============================================
-- TEST 1: Room Messages Query (Most Common)
-- Expected: Uses idx_messages_room_time
-- Performance Target: <30ms
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING)
SELECT 
  id,
  room_id,
  sender_id,
  content_preview,
  created_at
FROM messages
WHERE room_id = (
  SELECT id FROM rooms LIMIT 1
)
ORDER BY created_at DESC
LIMIT 50;

-- ===============================================
-- TEST 2: Unread Messages Count
-- Expected: Uses idx_message_receipts_user_unread
-- Performance Target: <50ms
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING)
SELECT COUNT(*)
FROM message_receipts
WHERE user_id = (
  SELECT id FROM users LIMIT 1
)
  AND read_at IS NULL;

-- ===============================================
-- TEST 3: User's Rooms
-- Expected: Uses idx_rooms_created_by
-- Performance Target: <20ms
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING)
SELECT 
  id,
  slug,
  title,
  created_at
FROM rooms
WHERE created_by = (
  SELECT id FROM users LIMIT 1
)
ORDER BY created_at DESC;

-- ===============================================
-- TEST 4: Room Membership Check
-- Expected: Uses idx_room_memberships_room_user
-- Performance Target: <10ms
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING)
SELECT 
  id,
  role,
  joined_at
FROM room_memberships
WHERE room_id = (
  SELECT id FROM rooms LIMIT 1
)
  AND user_id = (
    SELECT id FROM users LIMIT 1
  );

-- ===============================================
-- TEST 5: Pending Retention Jobs
-- Expected: Uses idx_retention_schedule_pending
-- Performance Target: <50ms
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING)
SELECT 
  id,
  resource_type,
  resource_id,
  scheduled_for,
  action
FROM retention_schedule
WHERE status = 'pending'
  AND scheduled_for <= NOW()
ORDER BY scheduled_for ASC
LIMIT 100;

-- ===============================================
-- TEST 6: Active Legal Holds
-- Expected: Uses idx_legal_holds_active
-- Performance Target: <20ms
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING)
SELECT 
  id,
  resource_type,
  resource_id,
  hold_until
FROM legal_holds
WHERE resource_type = 'logs_compressed'
  AND hold_until > NOW()
LIMIT 10;

-- ===============================================
-- TEST 7: Public Rooms Discovery
-- Expected: Uses idx_rooms_public_recent
-- Performance Target: <30ms
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING)
SELECT 
  id,
  slug,
  title,
  created_at
FROM rooms
WHERE is_public = true
ORDER BY created_at DESC
LIMIT 20;

-- ===============================================
-- TEST 8: Full-Text Search
-- Expected: Uses idx_messages_content_preview_gin
-- Performance Target: <100ms
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING)
SELECT 
  id,
  room_id,
  content_preview,
  created_at,
  ts_rank(to_tsvector('english', content_preview), plainto_tsquery('english', 'test')) AS rank
FROM messages
WHERE to_tsvector('english', content_preview) @@ plainto_tsquery('english', 'test')
ORDER BY rank DESC, created_at DESC
LIMIT 20;

-- ===============================================
-- TEST 9: Vector Similarity Search
-- Expected: Uses idx_embeddings_vector (HNSW)
-- Performance Target: <100ms
-- ===============================================

-- Note: This test requires actual vector data
-- Uncomment and adjust if you have embeddings data
/*
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING)
SELECT 
  e.message_id,
  m.content_preview,
  1 - (e.vector <=> (SELECT vector FROM embeddings LIMIT 1)) AS similarity
FROM embeddings e
JOIN messages m ON m.id = e.message_id
WHERE 1 - (e.vector <=> (SELECT vector FROM embeddings LIMIT 1)) > 0.78
ORDER BY e.vector <=> (SELECT vector FROM embeddings LIMIT 1)
LIMIT 10;
*/

-- ===============================================
-- TEST 10: Thread Messages
-- Expected: Uses idx_messages_thread_id_composite
-- Performance Target: <30ms
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING)
SELECT 
  id,
  thread_id,
  sender_id,
  content_preview,
  created_at
FROM messages
WHERE thread_id IN (
  SELECT id FROM threads LIMIT 1
)
ORDER BY created_at ASC;

-- ===============================================
-- INDEX USAGE STATISTICS
-- Shows which indexes are being used and how often
-- ===============================================

SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan AS index_scans,
  idx_tup_read AS tuples_read,
  idx_tup_fetch AS tuples_fetched,
  CASE 
    WHEN idx_scan = 0 THEN '⚠️ UNUSED'
    WHEN idx_scan < 100 THEN '🟡 LOW'
    WHEN idx_scan < 1000 THEN '🟢 MEDIUM'
    ELSE '✅ HIGH'
  END AS usage_level
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY idx_scan DESC
LIMIT 50;

-- ===============================================
-- TABLE SIZE STATISTICS
-- Shows table and index sizes
-- ===============================================

SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS index_size,
  CASE 
    WHEN pg_total_relation_size(schemaname||'.'||tablename) > 1073741824 THEN '🔴 LARGE (>1GB)'
    WHEN pg_total_relation_size(schemaname||'.'||tablename) > 104857600 THEN '🟡 MEDIUM (>100MB)'
    ELSE '🟢 SMALL'
  END AS size_category
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- ===============================================
-- SLOW QUERY DETECTION (if pg_stat_statements enabled)
-- ===============================================

SELECT 
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  max_exec_time,
  ROUND(100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0), 2) AS cache_hit_ratio
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
  AND mean_exec_time > 100  -- Queries taking >100ms on average
ORDER BY mean_exec_time DESC
LIMIT 20;

