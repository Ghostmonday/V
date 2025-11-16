-- ===============================================
-- Supabase Schema Test Script
-- Purpose: Test all tables, columns, and basic operations
-- Run this in Supabase SQL Editor to verify everything works
-- ===============================================

-- Test Results Summary
DO $$
DECLARE
    test_results TEXT[] := ARRAY[]::TEXT[];
    test_count INT := 0;
    pass_count INT := 0;
    fail_count INT := 0;
    test_result TEXT;
BEGIN
    RAISE NOTICE '🧪 Starting Supabase Schema Tests...';
    RAISE NOTICE '';

    -- ===============================================
    -- TEST 1: Check Critical Tables Exist
    -- ===============================================
    test_count := test_count + 1;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
        test_results := array_append(test_results, '✅ TEST 1: users table exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 1: users table MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rooms') THEN
        test_results := array_append(test_results, '✅ TEST 2: rooms table exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 2: rooms table MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'messages') THEN
        test_results := array_append(test_results, '✅ TEST 3: messages table exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 3: messages table MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'usage_stats') THEN
        test_results := array_append(test_results, '✅ TEST 4: usage_stats table exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 4: usage_stats table MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'config') THEN
        test_results := array_append(test_results, '✅ TEST 5: config table exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 5: config table MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'files') THEN
        test_results := array_append(test_results, '✅ TEST 6: files table exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 6: files table MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'threads') THEN
        test_results := array_append(test_results, '✅ TEST 7: threads table exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 7: threads table MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'edit_history') THEN
        test_results := array_append(test_results, '✅ TEST 8: edit_history table exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 8: edit_history table MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bot_endpoints') THEN
        test_results := array_append(test_results, '✅ TEST 9: bot_endpoints table exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 9: bot_endpoints table MISSING');
        fail_count := fail_count + 1;
    END IF;

    -- ===============================================
    -- TEST 10-12: Check Critical Columns
    -- ===============================================
    test_count := test_count + 1;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'subscription'
    ) THEN
        test_results := array_append(test_results, '✅ TEST 10: users.subscription column exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 10: users.subscription column MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'password_hash'
    ) THEN
        test_results := array_append(test_results, '✅ TEST 11: users.password_hash column exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 11: users.password_hash column MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'usage_stats' AND column_name = 'metadata'
    ) THEN
        test_results := array_append(test_results, '✅ TEST 12: usage_stats.metadata column exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 12: usage_stats.metadata column MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'messages' AND column_name = 'reactions'
    ) THEN
        test_results := array_append(test_results, '✅ TEST 13: messages.reactions column exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 13: messages.reactions column MISSING');
        fail_count := fail_count + 1;
    END IF;

    test_count := test_count + 1;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'messages' AND column_name = 'thread_id'
    ) THEN
        test_results := array_append(test_results, '✅ TEST 14: messages.thread_id column exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 14: messages.thread_id column MISSING');
        fail_count := fail_count + 1;
    END IF;

    -- ===============================================
    -- TEST 15-17: Test Basic CRUD Operations
    -- ===============================================
    
    -- Test INSERT into config
    BEGIN
        INSERT INTO config (key, value) 
        VALUES ('test_key', '{"test": "value"}'::jsonb)
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
        test_count := test_count + 1;
        test_results := array_append(test_results, '✅ TEST 15: Can INSERT into config table');
        pass_count := pass_count + 1;
    EXCEPTION WHEN OTHERS THEN
        test_count := test_count + 1;
        test_results := array_append(test_results, '❌ TEST 15: Cannot INSERT into config - ' || SQLERRM);
        fail_count := fail_count + 1;
    END;

    -- Test SELECT from config
    BEGIN
        PERFORM * FROM config WHERE key = 'test_key' LIMIT 1;
        test_count := test_count + 1;
        test_results := array_append(test_results, '✅ TEST 16: Can SELECT from config table');
        pass_count := pass_count + 1;
    EXCEPTION WHEN OTHERS THEN
        test_count := test_count + 1;
        test_results := array_append(test_results, '❌ TEST 16: Cannot SELECT from config - ' || SQLERRM);
        fail_count := fail_count + 1;
    END;

    -- Test INSERT into usage_stats
    BEGIN
        INSERT INTO usage_stats (user_id, event_type, metadata, ts)
        VALUES ('test_user_123', 'test_event', '{"amount": 1}'::jsonb, NOW());
        test_count := test_count + 1;
        test_results := array_append(test_results, '✅ TEST 17: Can INSERT into usage_stats table');
        pass_count := pass_count + 1;
        
        -- Clean up test data
        DELETE FROM usage_stats WHERE user_id = 'test_user_123' AND event_type = 'test_event';
    EXCEPTION WHEN OTHERS THEN
        test_count := test_count + 1;
        test_results := array_append(test_results, '❌ TEST 17: Cannot INSERT into usage_stats - ' || SQLERRM);
        fail_count := fail_count + 1;
    END;

    -- ===============================================
    -- TEST 18: Check Functions Exist
    -- ===============================================
    test_count := test_count + 1;
    IF EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'update_thread_metadata'
    ) THEN
        test_results := array_append(test_results, '✅ TEST 18: update_thread_metadata function exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 18: update_thread_metadata function MISSING');
        fail_count := fail_count + 1;
    END IF;

    -- ===============================================
    -- TEST 19: Check Materialized View Exists
    -- ===============================================
    test_count := test_count + 1;
    IF EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'message_search_index'
    ) THEN
        test_results := array_append(test_results, '✅ TEST 19: message_search_index view exists');
        pass_count := pass_count + 1;
    ELSE
        test_results := array_append(test_results, '❌ TEST 19: message_search_index view MISSING');
        fail_count := fail_count + 1;
    END IF;

    -- ===============================================
    -- Print Results
    -- ===============================================
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 TEST RESULTS SUMMARY';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '';
    
    FOREACH test_result IN ARRAY test_results
    LOOP
        RAISE NOTICE '%', test_result;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE 'Total Tests: %', test_count;
    RAISE NOTICE 'Passed: % ✅', pass_count;
    RAISE NOTICE 'Failed: % ❌', fail_count;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    
    IF fail_count = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '🎉 ALL TESTS PASSED! Schema is ready for integration.';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  Some tests failed. Please review and fix missing components.';
    END IF;
END $$;

-- ===============================================
-- Additional Verification Queries
-- ===============================================

-- Show all tables
SELECT 
    '📋 All Tables' as info,
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE columns.table_name = tables.table_name) as column_count
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Show critical columns
SELECT 
    '🔑 Critical Columns' as info,
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE (table_name = 'users' AND column_name IN ('subscription', 'password_hash'))
   OR (table_name = 'usage_stats' AND column_name = 'metadata')
   OR (table_name = 'messages' AND column_name IN ('reactions', 'thread_id', 'reply_to', 'is_edited'))
ORDER BY table_name, column_name;

-- Show indexes on critical tables
SELECT 
    '📇 Indexes' as info,
    tablename as table_name,
    indexname as index_name
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('users', 'messages', 'usage_stats', 'threads', 'config', 'files')
ORDER BY tablename, indexname;

