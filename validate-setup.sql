-- ===============================================
-- COMPREHENSIVE SETUP VALIDATION
-- Run this in Supabase SQL Editor to verify everything is working
-- ===============================================

-- 1. CHECK EXTENSIONS
SELECT 
  'Extensions' as check_type,
  extname as name,
  CASE 
    WHEN extname IN ('pgcrypto', 'pg_stat_statements', 'uuid-ossp') THEN '✅ REQUIRED'
    ELSE '📦 OPTIONAL'
  END as status
FROM pg_extension
WHERE extname IN ('pgcrypto', 'pg_stat_statements', 'uuid-ossp')
ORDER BY extname;

-- 2. CHECK ALL TABLES EXIST
SELECT 
  'Tables' as check_type,
  table_name as name,
  CASE 
    WHEN table_name IN ('users', 'rooms', 'messages', 'room_members', 'api_keys') 
    THEN '✅ CRITICAL'
    ELSE '📋 OPTIONAL'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'users', 'rooms', 'messages', 'room_members', 'room_memberships',
    'read_receipts', 'message_receipts', 'reactions', 'threads',
    'subscriptions', 'files', 'telemetry', 'ux_telemetry', 'presence_logs',
    'pinned_items', 'nicknames', 'config', 'api_keys'
  )
ORDER BY 
  CASE 
    WHEN table_name IN ('users', 'rooms', 'messages', 'room_members', 'api_keys') 
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
  AND tablename IN ('users', 'rooms', 'messages', 'telemetry', 'room_members', 'subscriptions', 'api_keys')
ORDER BY tablename;

-- 4. CHECK RLS POLICIES EXIST
SELECT 
  'RLS Policies' as check_type,
  schemaname || '.' || tablename || '.' || policyname as name,
  '✅ EXISTS' as status
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('users', 'rooms', 'messages', 'api_keys')
ORDER BY tablename, policyname;

-- 5. CHECK FUNCTIONS EXIST
SELECT 
  'Functions' as check_type,
  p.proname as name,
  '✅ EXISTS' as status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('get_encryption_key', 'store_api_key', 'get_api_key', 'current_uid')
ORDER BY p.proname;

-- 6. CHECK INDEXES EXIST
SELECT 
  'Indexes' as check_type,
  indexname as name,
  '✅ EXISTS' as status
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY indexname;

-- 7. TEST DATA OPERATIONS (Run as service_role)
-- This will test if you can actually insert/read data
DO $$
DECLARE
  test_user_id UUID;
  test_room_id UUID;
  test_message_id UUID;
  test_result TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TESTING DATA OPERATIONS';
  RAISE NOTICE '========================================';
  
  -- Test 1: Insert a test user
  BEGIN
    INSERT INTO users (handle, display_name, age_verified)
    VALUES ('test_validation_' || extract(epoch from now())::text, 'Test User', true)
    RETURNING id INTO test_user_id;
    RAISE NOTICE '✅ Test 1: User insert successful - ID: %', test_user_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Test 1: User insert failed - %', SQLERRM;
    test_user_id := NULL;
  END;
  
  -- Test 2: Insert a test room (if user was created)
  IF test_user_id IS NOT NULL THEN
    BEGIN
      INSERT INTO rooms (name, creator_id, is_public)
      VALUES ('test-room-' || extract(epoch from now())::text, test_user_id, true)
      RETURNING id INTO test_room_id;
      RAISE NOTICE '✅ Test 2: Room insert successful - ID: %', test_room_id;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '❌ Test 2: Room insert failed - %', SQLERRM;
      test_room_id := NULL;
    END;
  ELSE
    RAISE NOTICE '⏭️  Test 2: Skipped (user creation failed)';
  END IF;
  
  -- Test 3: Insert a test message (if room was created)
  IF test_room_id IS NOT NULL AND test_user_id IS NOT NULL THEN
    BEGIN
      INSERT INTO messages (room_id, user_id, sender_id, content)
      VALUES (test_room_id, test_user_id, test_user_id, 'Test validation message')
      RETURNING id INTO test_message_id;
      RAISE NOTICE '✅ Test 3: Message insert successful - ID: %', test_message_id;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '❌ Test 3: Message insert failed - %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE '⏭️  Test 3: Skipped (prerequisites failed)';
  END IF;
  
  -- Test 4: Test API key function (encryption)
  BEGIN
    PERFORM get_encryption_key();
    RAISE NOTICE '✅ Test 4: get_encryption_key() function works';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Test 4: get_encryption_key() failed - %', SQLERRM;
  END;
  
  -- Test 5: Test current_uid() function
  BEGIN
    PERFORM current_uid();
    RAISE NOTICE '✅ Test 5: current_uid() function works (may return NULL if no auth context)';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Test 5: current_uid() failed - %', SQLERRM;
  END;
  
  -- Cleanup: Delete test data
  IF test_message_id IS NOT NULL THEN
    BEGIN
      DELETE FROM messages WHERE id = test_message_id;
      RAISE NOTICE '✅ Cleanup: Test message deleted';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '⚠️  Cleanup: Failed to delete test message - %', SQLERRM;
    END;
  END IF;
  
  IF test_room_id IS NOT NULL THEN
    BEGIN
      DELETE FROM rooms WHERE id = test_room_id;
      RAISE NOTICE '✅ Cleanup: Test room deleted';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '⚠️  Cleanup: Failed to delete test room - %', SQLERRM;
    END;
  END IF;
  
  IF test_user_id IS NOT NULL THEN
    BEGIN
      DELETE FROM users WHERE id = test_user_id;
      RAISE NOTICE '✅ Cleanup: Test user deleted';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '⚠️  Cleanup: Failed to delete test user - %', SQLERRM;
    END;
  END IF;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VALIDATION COMPLETE';
  RAISE NOTICE '========================================';
END $$;

-- 8. CHECK FOREIGN KEY CONSTRAINTS
SELECT 
  'Foreign Keys' as check_type,
  tc.table_name || '.' || kcu.column_name || ' -> ' || ccu.table_name || '.' || ccu.column_name as name,
  '✅ EXISTS' as status
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;

-- 9. SUMMARY STATISTICS
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
  'Total Indexes' as name,
  COUNT(*)::TEXT as status
FROM pg_indexes
WHERE schemaname = 'public'

UNION ALL

SELECT 
  'SUMMARY' as check_type,
  'Total Functions' as name,
  COUNT(*)::TEXT as status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'

UNION ALL

SELECT 
  'SUMMARY' as check_type,
  'Total RLS Policies' as name,
  COUNT(*)::TEXT as status
FROM pg_policies
WHERE schemaname = 'public';

-- 10. CHECK FOR COMMON ISSUES
DO $$
DECLARE
  issue_count INT := 0;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CHECKING FOR COMMON ISSUES';
  RAISE NOTICE '========================================';
  
  -- Check if users table has RLS enabled but no policies
  IF EXISTS (
    SELECT 1 FROM pg_tables t
    JOIN pg_class c ON c.relname = t.tablename
    WHERE t.schemaname = 'public' 
      AND t.tablename = 'users'
      AND c.relrowsecurity = true
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users'
  ) THEN
    RAISE WARNING '⚠️  ISSUE: users table has RLS enabled but no policies!';
    issue_count := issue_count + 1;
  ELSE
    RAISE NOTICE '✅ users table RLS policies OK';
  END IF;
  
  -- Check if api_keys table exists and has proper structure
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'api_keys'
  ) THEN
    RAISE WARNING '⚠️  ISSUE: api_keys table missing!';
    issue_count := issue_count + 1;
  ELSE
    RAISE NOTICE '✅ api_keys table exists';
  END IF;
  
  -- Check if required functions exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'current_uid'
  ) THEN
    RAISE WARNING '⚠️  ISSUE: current_uid() function missing!';
    issue_count := issue_count + 1;
  ELSE
    RAISE NOTICE '✅ current_uid() function exists';
  END IF;
  
  -- Check if pgcrypto extension is installed
  IF NOT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto'
  ) THEN
    RAISE WARNING '⚠️  ISSUE: pgcrypto extension not installed!';
    issue_count := issue_count + 1;
  ELSE
    RAISE NOTICE '✅ pgcrypto extension installed';
  END IF;
  
  IF issue_count = 0 THEN
    RAISE NOTICE '✅ No issues found!';
  ELSE
    RAISE WARNING '⚠️  Found % issue(s) - review warnings above', issue_count;
  END IF;
END $$;

