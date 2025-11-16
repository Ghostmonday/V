-- ===============================================
-- QUICK SUPABASE VALIDATION SCRIPT
-- ===============================================
-- Run this in Supabase SQL Editor after setup
-- This will quickly verify your database is configured correctly
-- ===============================================

-- 1. CHECK EXTENSIONS
SELECT 
    'Extensions' as check_type,
    extname as name,
    CASE 
        WHEN extname IN ('pgcrypto', 'pg_stat_statements') THEN '✅ REQUIRED'
        WHEN extname = 'vector' THEN '📦 OPTIONAL (for semantic search)'
        ELSE '📋 OTHER'
    END as status
FROM pg_extension
WHERE extname IN ('pgcrypto', 'pg_stat_statements', 'vector')
ORDER BY 
    CASE 
        WHEN extname IN ('pgcrypto', 'pg_stat_statements') THEN 1
        WHEN extname = 'vector' THEN 2
        ELSE 3
    END;

-- 2. CHECK CORE TABLES
SELECT 
    'Core Tables' as check_type,
    table_name as name,
    CASE 
        WHEN table_name IN ('users', 'rooms', 'messages', 'room_memberships', 'message_receipts') 
        THEN '✅ CRITICAL'
        ELSE '📋 OPTIONAL'
    END as status
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_name IN (
        'users', 'rooms', 'messages', 'room_memberships', 
        'message_receipts', 'audit_log', 'telemetry', 
        'threads', 'assistants', 'bots', 'subscriptions',
        'embeddings', 'metrics', 'presence_logs'
    )
ORDER BY 
    CASE 
        WHEN table_name IN ('users', 'rooms', 'messages', 'room_memberships', 'message_receipts') 
        THEN 1 
        ELSE 2 
    END,
    table_name;

-- 3. CHECK RLS STATUS
SELECT 
    'RLS Status' as check_type,
    tablename as name,
    CASE 
        WHEN relrowsecurity THEN '✅ ENABLED'
        ELSE '❌ DISABLED'
    END as status
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public'
    AND tablename IN ('users', 'rooms', 'messages', 'telemetry', 'audit_log', 'room_memberships')
ORDER BY tablename;

-- 4. COUNT RLS POLICIES
SELECT 
    'RLS Policies' as check_type,
    tablename as name,
    COUNT(*)::TEXT || ' policies' as status
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY COUNT(*) DESC, tablename
LIMIT 10;

-- 5. COUNT INDEXES
SELECT 
    'Indexes' as check_type,
    tablename as name,
    COUNT(*)::TEXT || ' indexes' as status
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexname LIKE 'idx_%'
GROUP BY tablename
ORDER BY COUNT(*) DESC, tablename
LIMIT 10;

-- 6. CHECK HELPER FUNCTIONS
SELECT 
    'Helper Functions' as check_type,
    p.proname as name,
    '✅ EXISTS' as status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
    AND p.proname IN ('current_uid', 'current_role', 'is_moderator', 'allowed_bots')
ORDER BY p.proname;

-- 7. SUMMARY STATISTICS
SELECT 
    'SUMMARY' as check_type,
    'Total Tables' as name,
    COUNT(*)::TEXT as status
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE'
UNION ALL
SELECT 
    'SUMMARY' as check_type,
    'Total RLS Policies' as name,
    COUNT(*)::TEXT as status
FROM pg_policies
WHERE schemaname = 'public'
UNION ALL
SELECT 
    'SUMMARY' as check_type,
    'Total Indexes' as name,
    COUNT(*)::TEXT as status
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexname LIKE 'idx_%'
UNION ALL
SELECT 
    'SUMMARY' as check_type,
    'Total Functions' as name,
    COUNT(*)::TEXT as status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
    AND p.proname IN ('current_uid', 'current_role', 'is_moderator', 'allowed_bots');

-- 8. QUICK TEST: Can we insert a test user?
DO $$
DECLARE
    test_user_id UUID;
BEGIN
    -- Try to insert a test user
    INSERT INTO users (handle, display_name)
    VALUES ('validation_test_' || extract(epoch from now())::text, 'Validation Test User')
    RETURNING id INTO test_user_id;
    
    RAISE NOTICE '✅ Test user created successfully: %', test_user_id;
    
    -- Clean up
    DELETE FROM users WHERE id = test_user_id;
    RAISE NOTICE '✅ Test user cleaned up';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Error creating test user: %', SQLERRM;
END $$;

-- FINAL STATUS
SELECT 
    '✅ VALIDATION COMPLETE' as status,
    'Check results above. All critical items should show ✅' as note;

