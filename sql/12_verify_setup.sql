-- ===============================================
-- FILE: 12_verify_setup.sql
-- PURPOSE: Diagnostic script to verify all indexes, RLS policies, AI views, and functions
-- USAGE: Run AFTER 11_indexing_and_rls.sql to confirm everything is working
-- 
-- IMPORTANT: This script will check if views exist before querying them.
-- If views don't exist, you'll see warnings but the script will still complete.
-- ===============================================

-- ===============================================
-- 1. VERIFY INDEXES (30+ indexes)
-- ===============================================

DO $$
DECLARE
  idx_count INT;
  expected_indexes TEXT[] := ARRAY[
    'idx_telemetry_event',
    'idx_telemetry_event_time',
    'idx_telemetry_user_id',
    'idx_telemetry_room_id',
    'idx_telemetry_msg_sent',
    'idx_logs_raw_created_at',
    'idx_logs_raw_room_created',
    'idx_audit_log_action',
    'idx_audit_log_entity_id',
    'idx_audit_log_timestamp',
    'idx_metrics_type_target',
    'idx_metrics_type_timestamp',
    'idx_metrics_created_at',
    'idx_users_handle',
    'idx_users_created_at',
    'idx_users_metadata_email',
    'idx_presence_logs_room_user',
    'idx_presence_logs_user_created',
    'idx_presence_logs_room_created',
    'idx_room_memberships_room_user',
    'idx_room_memberships_user_role',
    'idx_room_memberships_role',
    'idx_bots_name',
    'idx_bots_created_by',
    'idx_bots_is_active',
    'idx_bot_endpoints_bot_status',
    'idx_bot_endpoints_status',
    'idx_room_memberships_user_room_composite',
    'idx_messages_sender_created',
    'idx_messages_thread_id_composite',
    'idx_embeddings_message_id_created'
  ];
  missing_indexes TEXT[] := ARRAY[]::TEXT[];
  idx_name TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'INDEX VERIFICATION';
  RAISE NOTICE '========================================';
  
  FOREACH idx_name IN ARRAY expected_indexes
  LOOP
    SELECT COUNT(*) INTO idx_count
    FROM pg_indexes
    WHERE indexname = idx_name;
    
    IF idx_count = 0 THEN
      missing_indexes := array_append(missing_indexes, idx_name);
      RAISE NOTICE '❌ MISSING: %', idx_name;
    ELSE
      RAISE NOTICE '✅ FOUND: %', idx_name;
    END IF;
  END LOOP;
  
  IF array_length(missing_indexes, 1) IS NULL THEN
    RAISE NOTICE '✅ ALL % INDEXES VERIFIED', array_length(expected_indexes, 1);
  ELSE
    RAISE NOTICE '⚠️  MISSING % INDEXES: %', array_length(missing_indexes, 1), missing_indexes;
  END IF;
END $$;

-- ===============================================
-- 2. VERIFY RLS ENABLED ON TABLES
-- ===============================================

DO $$
DECLARE
  rls_count INT;
  expected_tables TEXT[] := ARRAY[
    'telemetry',
    'messages',
    'bots',
    'audit_log',
    'presence_logs',
    'embeddings',
    'subscriptions',
    'assistants',
    'threads',
    'room_memberships'
  ];
  missing_rls TEXT[] := ARRAY[]::TEXT[];
  tbl_name TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RLS ENABLED VERIFICATION';
  RAISE NOTICE '========================================';
  
  FOREACH tbl_name IN ARRAY expected_tables
  LOOP
    SELECT COUNT(*) INTO rls_count
    FROM pg_tables t
    JOIN pg_class c ON c.relname = t.tablename
    WHERE t.schemaname = 'public'
      AND t.tablename = tbl_name
      AND c.relrowsecurity = TRUE;
    
    IF rls_count = 0 THEN
      missing_rls := array_append(missing_rls, tbl_name);
      RAISE NOTICE '❌ RLS NOT ENABLED: %', tbl_name;
    ELSE
      RAISE NOTICE '✅ RLS ENABLED: %', tbl_name;
    END IF;
  END LOOP;
  
  IF array_length(missing_rls, 1) IS NULL THEN
    RAISE NOTICE '✅ ALL % TABLES HAVE RLS ENABLED', array_length(expected_tables, 1);
  ELSE
    RAISE NOTICE '⚠️  RLS MISSING ON % TABLES: %', array_length(missing_rls, 1), missing_rls;
  END IF;
END $$;

-- ===============================================
-- 3. VERIFY RLS POLICIES EXIST
-- ===============================================

DO $$
DECLARE
  policy_count INT;
  expected_policies TEXT[] := ARRAY[
    'telemetry_read_own',
    'messages_read_own',
    'messages_write_own',
    'messages_update_own',
    'bots_read_own',
    'bots_write_own',
    'bots_update_own',
    'bots_delete_own',
    'audit_logs_read_moderators',
    'presence_logs_read_own',
    'embeddings_read_own',
    'embeddings_write_own',
    'subscriptions_read_own',
    'subscriptions_write_own',
    'subscriptions_update_own',
    'subscriptions_delete_own',
    'assistants_read_own',
    'assistants_write_own',
    'assistants_update_own',
    'assistants_delete_own',
    'threads_read_member',
    'threads_write_member',
    'room_memberships_read_member'
  ];
  missing_policies TEXT[] := ARRAY[]::TEXT[];
  policy_name TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RLS POLICIES VERIFICATION';
  RAISE NOTICE '========================================';
  
  FOREACH policy_name IN ARRAY expected_policies
  LOOP
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE policyname = policy_name;
    
    IF policy_count = 0 THEN
      missing_policies := array_append(missing_policies, policy_name);
      RAISE NOTICE '❌ MISSING POLICY: %', policy_name;
    ELSE
      RAISE NOTICE '✅ FOUND POLICY: %', policy_name;
    END IF;
  END LOOP;
  
  IF array_length(missing_policies, 1) IS NULL THEN
    RAISE NOTICE '✅ ALL % RLS POLICIES VERIFIED', array_length(expected_policies, 1);
  ELSE
    RAISE NOTICE '⚠️  MISSING % POLICIES: %', array_length(missing_policies, 1), missing_policies;
  END IF;
END $$;

-- ===============================================
-- 4. VERIFY HELPER FUNCTIONS EXIST
-- ===============================================

DO $$
DECLARE
  func_count INT;
  expected_functions TEXT[] := ARRAY[
    'current_uid',
    'current_role',
    'is_moderator',
    'allowed_bots'
  ];
  missing_functions TEXT[] := ARRAY[]::TEXT[];
  func_name TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'HELPER FUNCTIONS VERIFICATION';
  RAISE NOTICE '========================================';
  
  FOREACH func_name IN ARRAY expected_functions
  LOOP
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = func_name;
    
    IF func_count = 0 THEN
      missing_functions := array_append(missing_functions, func_name);
      RAISE NOTICE '❌ MISSING FUNCTION: %', func_name;
    ELSE
      RAISE NOTICE '✅ FOUND FUNCTION: %', func_name;
    END IF;
  END LOOP;
  
  IF array_length(missing_functions, 1) IS NULL THEN
    RAISE NOTICE '✅ ALL % HELPER FUNCTIONS VERIFIED', array_length(expected_functions, 1);
  ELSE
    RAISE NOTICE '⚠️  MISSING % FUNCTIONS: %', array_length(missing_functions, 1), missing_functions;
  END IF;
END $$;

-- ===============================================
-- 5. VERIFY AI VIEWS EXIST
-- ===============================================

DO $$
DECLARE
  view_count INT;
  expected_views TEXT[] := ARRAY[
    'ai_bot_monitoring',
    'ai_message_quality',
    'ai_presence_trends',
    'ai_audit_summary',
    'ai_query_performance',
    'ai_moderation_suggestions',
    'ai_telemetry_insights'
  ];
  missing_views TEXT[] := ARRAY[]::TEXT[];
  view_name TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'AI VIEWS VERIFICATION';
  RAISE NOTICE '========================================';
  
  FOREACH view_name IN ARRAY expected_views
  LOOP
    SELECT COUNT(*) INTO view_count
    FROM pg_views
    WHERE viewname = view_name
      AND schemaname = 'public';
    
    IF view_count = 0 THEN
      missing_views := array_append(missing_views, view_name);
      RAISE NOTICE '❌ MISSING VIEW: %', view_name;
    ELSE
      RAISE NOTICE '✅ FOUND VIEW: %', view_name;
    END IF;
  END LOOP;
  
  IF array_length(missing_views, 1) IS NULL THEN
    RAISE NOTICE '✅ ALL % AI VIEWS VERIFIED', array_length(expected_views, 1);
  ELSE
    RAISE NOTICE '⚠️  MISSING % VIEWS: %', array_length(missing_views, 1), missing_views;
  END IF;
END $$;

-- ===============================================
-- 6. VERIFY AI FUNCTIONS EXIST
-- ===============================================

DO $$
DECLARE
  func_count INT;
  expected_functions TEXT[] := ARRAY[
    'ai_analyze_bot_failures',
    'ai_moderation_recommendations',
    'ai_detect_presence_dropouts'
  ];
  missing_functions TEXT[] := ARRAY[]::TEXT[];
  func_name TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'AI FUNCTIONS VERIFICATION';
  RAISE NOTICE '========================================';
  
  FOREACH func_name IN ARRAY expected_functions
  LOOP
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = func_name;
    
    IF func_count = 0 THEN
      missing_functions := array_append(missing_functions, func_name);
      RAISE NOTICE '❌ MISSING FUNCTION: %', func_name;
    ELSE
      RAISE NOTICE '✅ FOUND FUNCTION: %', func_name;
    END IF;
  END LOOP;
  
  IF array_length(missing_functions, 1) IS NULL THEN
    RAISE NOTICE '✅ ALL % AI FUNCTIONS VERIFIED', array_length(expected_functions, 1);
  ELSE
    RAISE NOTICE '⚠️  MISSING % FUNCTIONS: %', array_length(missing_functions, 1), missing_functions;
  END IF;
END $$;

-- ===============================================
-- 7. TEST AI VIEWS (Sample Queries)
-- ===============================================

DO $$
DECLARE
  row_count INT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'AI VIEWS TEST QUERIES';
  RAISE NOTICE '========================================';
  
  -- Test ai_bot_monitoring
  BEGIN
    SELECT COUNT(*) INTO row_count FROM ai_bot_monitoring;
    RAISE NOTICE '✅ ai_bot_monitoring: % rows', row_count;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ ai_bot_monitoring ERROR: %', SQLERRM;
  END;
  
  -- Test ai_telemetry_insights
  BEGIN
    SELECT COUNT(*) INTO row_count FROM ai_telemetry_insights;
    RAISE NOTICE '✅ ai_telemetry_insights: % rows', row_count;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ ai_telemetry_insights ERROR: %', SQLERRM;
  END;
  
  -- Test ai_message_quality
  BEGIN
    SELECT COUNT(*) INTO row_count FROM ai_message_quality;
    RAISE NOTICE '✅ ai_message_quality: % rows', row_count;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ ai_message_quality ERROR: %', SQLERRM;
  END;
  
  -- Test ai_moderation_suggestions
  BEGIN
    SELECT COUNT(*) INTO row_count FROM ai_moderation_suggestions;
    RAISE NOTICE '✅ ai_moderation_suggestions: % rows', row_count;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ ai_moderation_suggestions ERROR: %', SQLERRM;
  END;
END $$;

-- ===============================================
-- 8. TEST HELPER FUNCTIONS
-- ===============================================

DO $$
DECLARE
  test_result UUID;
  test_role TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'HELPER FUNCTIONS TEST';
  RAISE NOTICE '========================================';
  
  -- Test current_uid() (may return NULL if no JWT context)
  BEGIN
    test_result := public.current_uid();
    IF test_result IS NULL THEN
      RAISE NOTICE '⚠️  current_uid() returned NULL (expected if no JWT context)';
    ELSE
      RAISE NOTICE '✅ current_uid() works: %', test_result;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ current_uid() ERROR: %', SQLERRM;
  END;
  
  -- Test current_role() (use public schema to avoid conflict with built-in current_role)
  BEGIN
    test_role := public.current_role();
    RAISE NOTICE '✅ current_role() works: %', test_role;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ current_role() ERROR: %', SQLERRM;
  END;
  
  -- Test is_moderator() (will work even with NULL input)
  BEGIN
    PERFORM is_moderator(NULL::UUID);
    RAISE NOTICE '✅ is_moderator() works (tested with NULL)';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ is_moderator() ERROR: %', SQLERRM;
  END;
  
  -- Test allowed_bots() (will work even with NULL input)
  BEGIN
    PERFORM allowed_bots(NULL::UUID);
    RAISE NOTICE '✅ allowed_bots() works (tested with NULL)';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ allowed_bots() ERROR: %', SQLERRM;
  END;
END $$;

-- ===============================================
-- 9. SUMMARY STATISTICS
-- ===============================================

SELECT 
  'INDEXES' AS component,
  COUNT(*)::TEXT AS count
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
UNION ALL
SELECT 
  'RLS POLICIES' AS component,
  COUNT(*)::TEXT AS count
FROM pg_policies
WHERE schemaname = 'public'
UNION ALL
SELECT 
  'AI VIEWS' AS component,
  COUNT(*)::TEXT AS count
FROM pg_views
WHERE schemaname = 'public'
  AND viewname LIKE 'ai_%'
UNION ALL
SELECT 
  'HELPER FUNCTIONS' AS component,
  COUNT(*)::TEXT AS count
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('current_uid', 'current_role', 'is_moderator', 'allowed_bots')
UNION ALL
SELECT 
  'AI FUNCTIONS' AS component,
  COUNT(*)::TEXT AS count
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname LIKE 'ai_%';

-- ===============================================
-- 10. QUICK AI VIEW SAMPLES (if views exist)
-- ===============================================

DO $$
DECLARE
  view_exists BOOLEAN;
BEGIN
  -- Sample: ai_bot_monitoring (first 5 rows)
  BEGIN
    SELECT EXISTS (
      SELECT 1 FROM pg_views 
      WHERE viewname = 'ai_bot_monitoring' AND schemaname = 'public'
    ) INTO view_exists;
    
    IF view_exists THEN
      RAISE NOTICE '========================================';
      RAISE NOTICE 'AI VIEW SAMPLES';
      RAISE NOTICE '========================================';
      RAISE NOTICE 'Querying ai_bot_monitoring...';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️  ai_bot_monitoring view does not exist (run 11_indexing_and_rls.sql first)';
  END;
  
  -- Sample: ai_telemetry_insights (first 5 rows)
  BEGIN
    SELECT EXISTS (
      SELECT 1 FROM pg_views 
      WHERE viewname = 'ai_telemetry_insights' AND schemaname = 'public'
    ) INTO view_exists;
    
    IF view_exists THEN
      RAISE NOTICE 'Querying ai_telemetry_insights...';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️  ai_telemetry_insights view does not exist';
  END;
  
  -- Sample: ai_moderation_suggestions (all rows)
  BEGIN
    SELECT EXISTS (
      SELECT 1 FROM pg_views 
      WHERE viewname = 'ai_moderation_suggestions' AND schemaname = 'public'
    ) INTO view_exists;
    
    IF view_exists THEN
      RAISE NOTICE 'Querying ai_moderation_suggestions...';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️  ai_moderation_suggestions view does not exist';
  END;
END $$;

-- Only query views if they exist (wrapped in DO block to avoid errors)
DO $$
BEGIN
  -- Sample: ai_bot_monitoring
  IF EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'ai_bot_monitoring' AND schemaname = 'public') THEN
    RAISE NOTICE 'ai_bot_monitoring sample (first 5 rows):';
    -- Note: Can't use SELECT in DO block for display, but can verify it works
    PERFORM 1 FROM ai_bot_monitoring LIMIT 1;
    RAISE NOTICE '✅ ai_bot_monitoring is queryable';
  ELSE
    RAISE NOTICE '⚠️  ai_bot_monitoring does not exist - run sql/11_indexing_and_rls.sql first';
  END IF;
  
  -- Sample: ai_telemetry_insights
  IF EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'ai_telemetry_insights' AND schemaname = 'public') THEN
    PERFORM 1 FROM ai_telemetry_insights LIMIT 1;
    RAISE NOTICE '✅ ai_telemetry_insights is queryable';
  ELSE
    RAISE NOTICE '⚠️  ai_telemetry_insights does not exist - run sql/11_indexing_and_rls.sql first';
  END IF;
  
  -- Sample: ai_moderation_suggestions
  IF EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'ai_moderation_suggestions' AND schemaname = 'public') THEN
    PERFORM 1 FROM ai_moderation_suggestions LIMIT 1;
    RAISE NOTICE '✅ ai_moderation_suggestions is queryable';
  ELSE
    RAISE NOTICE '⚠️  ai_moderation_suggestions does not exist - run sql/11_indexing_and_rls.sql first';
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE '⚠️  Error querying views: %', SQLERRM;
END $$;

-- ===============================================
-- VERIFICATION COMPLETE
-- ===============================================

SELECT 
  '✅ VERIFICATION COMPLETE' AS status,
  'Check NOTICE messages above for detailed results' AS note;

