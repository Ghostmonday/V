-- ===============================================
-- Health Check Table Verification
-- ===============================================
-- This script verifies that the 'users' table exists and is accessible
-- The health check endpoint queries: SELECT id FROM users LIMIT 1
-- ===============================================

-- Check if users table exists
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'users'
        ) 
        THEN '✅ users table exists'
        ELSE '❌ users table NOT found'
    END AS table_status;

-- Check table structure (should have 'id' column)
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'users' 
            AND column_name = 'id'
        ) 
        THEN '✅ id column exists'
        ELSE '❌ id column NOT found'
    END AS column_status;

-- Test the actual health check query
-- This is what the application runs: SELECT id FROM users LIMIT 1
DO $$
DECLARE
    test_id TEXT;
    query_success BOOLEAN := false;
BEGIN
    BEGIN
        SELECT id INTO test_id FROM users LIMIT 1;
        query_success := true;
    EXCEPTION 
        WHEN OTHERS THEN
            query_success := false;
    END;
    
    IF query_success THEN
        RAISE NOTICE '✅ Health check query SUCCESSFUL';
        IF test_id IS NOT NULL THEN
            RAISE NOTICE '   Sample user ID: %', test_id;
        ELSE
            RAISE NOTICE '   Table exists but is empty (this is OK for health check)';
        END IF;
    ELSE
        RAISE EXCEPTION '❌ Health check query FAILED - users table not accessible';
    END IF;
END $$;

-- Show table info
SELECT 
    'users' AS table_name,
    COUNT(*) AS row_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Table has data'
        ELSE '⚠️  Table is empty (OK for health check)'
    END AS data_status
FROM users;

-- Summary
SELECT 
    'Health Check Verification Complete' AS status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'users'
        ) 
        THEN '✅ users table is ready for health checks'
        ELSE '❌ users table is missing - health checks will fail'
    END AS result;

