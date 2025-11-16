-- ============================================================================
-- TEST KEY RETRIEVAL - Verify keys can be retrieved and decrypted
-- ============================================================================

-- Test 1: Retrieve a single key
SELECT 'Test 1: Single Key Retrieval' AS test_name;
SELECT get_api_key('APPLE_TEAM_ID', 'production') AS apple_team_id;

-- Test 2: Retrieve JWT Secret
SELECT 'Test 2: JWT Secret Retrieval' AS test_name;
SELECT get_api_key('JWT_SECRET', 'production') AS jwt_secret;

-- Test 3: Retrieve Apple Private Key (should be full PEM)
SELECT 'Test 3: Apple Private Key Retrieval' AS test_name;
SELECT get_api_key('APPLE_PRIVATE_KEY', 'production') AS apple_private_key;

-- Test 4: Retrieve all Apple keys by category
SELECT 'Test 4: All Apple Keys by Category' AS test_name;
SELECT * FROM get_api_keys_by_category('apple', 'production');

-- Test 5: Retrieve all LiveKit keys
SELECT 'Test 5: All LiveKit Keys' AS test_name;
SELECT * FROM get_api_keys_by_category('livekit', 'production');

-- Test 6: Retrieve all Supabase keys
SELECT 'Test 6: All Supabase Keys' AS test_name;
SELECT * FROM get_api_keys_by_category('supabase', 'production');

-- Test 7: List all keys (metadata only - no values)
SELECT 'Test 7: List All Keys Metadata' AS test_name;
SELECT key_name, key_category, description, environment, is_active 
FROM list_api_keys('production') 
ORDER BY key_category, key_name
LIMIT 10;

-- Test 8: Verify specific key values match expected
SELECT 'Test 8: Verify Key Values' AS test_name;
SELECT 
    'APPLE_TEAM_ID' AS key_name,
    get_api_key('APPLE_TEAM_ID', 'production') AS retrieved_value,
    'R7KX4HNBFY' AS expected_value,
    CASE 
        WHEN get_api_key('APPLE_TEAM_ID', 'production') = 'R7KX4HNBFY' 
        THEN '✅ MATCH' 
        ELSE '❌ MISMATCH' 
    END AS status
UNION ALL
SELECT 
    'APPLE_KEY_ID' AS key_name,
    get_api_key('APPLE_KEY_ID', 'production') AS retrieved_value,
    '2D3E4F5G6H7I8J9K0L1M2' AS expected_value,
    CASE 
        WHEN get_api_key('APPLE_KEY_ID', 'production') = '2D3E4F5G6H7I8J9K0L1M2' 
        THEN '✅ MATCH' 
        ELSE '❌ MISMATCH' 
    END AS status
UNION ALL
SELECT 
    'JWT_SECRET' AS key_name,
    LEFT(get_api_key('JWT_SECRET', 'production'), 20) || '...' AS retrieved_value,
    LEFT('22b535f33e962ec929111875334a9911d12ea843b73137cfa8ff0162a8ec10d3', 20) || '...' AS expected_value,
    CASE 
        WHEN get_api_key('JWT_SECRET', 'production') = '22b535f33e962ec929111875334a9911d12ea843b73137cfa8ff0162a8ec10d3' 
        THEN '✅ MATCH' 
        ELSE '❌ MISMATCH' 
    END AS status;

-- Test 9: Check access tracking
SELECT 'Test 9: Access Tracking' AS test_name;
SELECT 
    key_name,
    access_count,
    last_accessed_at,
    CASE 
        WHEN last_accessed_at IS NOT NULL THEN '✅ Accessed'
        ELSE '⚠️ Never accessed'
    END AS access_status
FROM api_keys
WHERE key_name IN ('APPLE_TEAM_ID', 'JWT_SECRET', 'APPLE_KEY_ID')
ORDER BY key_name;

-- Test 10: Error handling - non-existent key
SELECT 'Test 10: Error Handling (Non-existent Key)' AS test_name;
DO $$
BEGIN
    BEGIN
        PERFORM get_api_key('NON_EXISTENT_KEY', 'production');
        RAISE NOTICE '❌ Should have raised an error';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '✅ Correctly raised error: %', SQLERRM;
    END;
END $$;

-- ============================================================================
-- SUMMARY: All tests complete
-- ============================================================================
SELECT '✅ All retrieval tests completed!' AS summary;

