-- ===============================================
-- Test Health Check Query
-- ===============================================
-- This is the EXACT query the health check runs
-- Run this in Supabase SQL Editor to verify it works
-- ===============================================

-- Health check query (exact query from checkSupabaseHealth function)
SELECT id FROM users LIMIT 1;

-- Expected result:
-- - If table has data: Returns one row with an id (UUID)
-- - If table is empty: Returns 0 rows (but no error - this is OK!)
-- - If table doesn't exist: Error "relation 'public.users' does not exist"

-- Additional verification
SELECT 
    'Health check query test' AS test_name,
    COUNT(*) AS row_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Table has data - health check will return a user ID'
        ELSE '⚠️  Table is empty - health check will return empty result (still OK)'
    END AS status
FROM users;

