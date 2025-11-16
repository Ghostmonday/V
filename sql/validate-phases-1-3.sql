-- ===============================================
-- Phase 1-3 Database Validation Script
-- Validates database schema and data integrity
-- ===============================================

-- Phase 1.1: Refresh Token Security
-- ===============================================
DO $$
DECLARE
    token_count INTEGER;
    hashed_count INTEGER;
    family_id_count INTEGER;
BEGIN
    -- Check refresh_tokens table exists
    SELECT COUNT(*) INTO token_count
    FROM information_schema.tables
    WHERE table_name = 'refresh_tokens';
    
    IF token_count = 0 THEN
        RAISE NOTICE '❌ Phase 1.1: refresh_tokens table does not exist';
    ELSE
        RAISE NOTICE '✅ Phase 1.1: refresh_tokens table exists';
        
        -- Check tokens are hashed (64 char hex)
        SELECT COUNT(*) INTO hashed_count
        FROM refresh_tokens
        WHERE LENGTH(token_hash) = 64 
          AND token_hash ~ '^[0-9a-f]{64}$';
        
        SELECT COUNT(*) INTO token_count FROM refresh_tokens;
        
        IF token_count > 0 AND hashed_count = token_count THEN
            RAISE NOTICE '✅ Phase 1.1: All tokens properly hashed (% tokens checked)', token_count;
        ELSIF token_count = 0 THEN
            RAISE NOTICE '⚠️  Phase 1.1: No tokens to check (table empty)';
        ELSE
            RAISE NOTICE '❌ Phase 1.1: Some tokens not properly hashed (%/% hashed)', hashed_count, token_count;
        END IF;
        
        -- Check family_id exists
        SELECT COUNT(*) INTO family_id_count
        FROM refresh_tokens
        WHERE family_id IS NOT NULL;
        
        IF token_count > 0 AND family_id_count = token_count THEN
            RAISE NOTICE '✅ Phase 1.1: All tokens have family_id';
        ELSIF token_count = 0 THEN
            RAISE NOTICE '⚠️  Phase 1.1: No tokens to check';
        ELSE
            RAISE NOTICE '❌ Phase 1.1: Some tokens missing family_id (%/% have family_id)', family_id_count, token_count;
        END IF;
    END IF;
END $$;

-- Check audit_logs table
DO $$
DECLARE
    audit_table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO audit_table_count
    FROM information_schema.tables
    WHERE table_name = 'audit_logs';
    
    IF audit_table_count > 0 THEN
        RAISE NOTICE '✅ Phase 1.1: audit_logs table exists';
    ELSE
        RAISE NOTICE '❌ Phase 1.1: audit_logs table missing';
    END IF;
END $$;

-- Phase 1.2: Password Security
-- ===============================================
DO $$
DECLARE
    user_count INTEGER;
    plaintext_count INTEGER;
    bcrypt_count INTEGER;
    argon2_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users;
    
    IF user_count = 0 THEN
        RAISE NOTICE '⚠️  Phase 1.2: No users to check';
    ELSE
        -- Check for plaintext passwords (not starting with $2 or $argon2)
        SELECT COUNT(*) INTO plaintext_count
        FROM users
        WHERE (password_hash IS NOT NULL OR password IS NOT NULL)
          AND COALESCE(password_hash, password) !~ '^\$2[aby]?\$'
          AND COALESCE(password_hash, password) !~ '^\$argon2';
        
        -- Check bcrypt hashes
        SELECT COUNT(*) INTO bcrypt_count
        FROM users
        WHERE COALESCE(password_hash, password) ~ '^\$2[aby]?\$';
        
        -- Check argon2 hashes
        SELECT COUNT(*) INTO argon2_count
        FROM users
        WHERE COALESCE(password_hash, password) ~ '^\$argon2';
        
        IF plaintext_count = 0 THEN
            RAISE NOTICE '✅ Phase 1.2: No plaintext passwords found (% users checked)', user_count;
        ELSE
            RAISE NOTICE '❌ Phase 1.2: Found % plaintext passwords', plaintext_count;
        END IF;
        
        RAISE NOTICE '   Hash formats: Bcrypt=% | Argon2=%', bcrypt_count, argon2_count;
    END IF;
END $$;

-- Phase 1.3: Role-Based Access Control
-- ===============================================
DO $$
DECLARE
    role_column_exists BOOLEAN;
    valid_roles TEXT[] := ARRAY['user', 'moderator', 'admin', 'owner'];
    invalid_role_count INTEGER;
BEGIN
    -- Check if role column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'role'
    ) INTO role_column_exists;
    
    IF role_column_exists THEN
        RAISE NOTICE '✅ Phase 1.3: role column exists in users table';
        
        -- Check for invalid roles
        SELECT COUNT(*) INTO invalid_role_count
        FROM users
        WHERE role IS NOT NULL
          AND role != ALL(valid_roles);
        
        IF invalid_role_count = 0 THEN
            RAISE NOTICE '✅ Phase 1.3: All roles are valid';
        ELSE
            RAISE NOTICE '❌ Phase 1.3: Found % users with invalid roles', invalid_role_count;
        END IF;
    ELSE
        RAISE NOTICE '❌ Phase 1.3: role column missing from users table';
    END IF;
END $$;

-- Phase 2.3: Delivery Acknowledgements
-- ===============================================
DO $$
DECLARE
    message_id_exists BOOLEAN;
    delivery_status_exists BOOLEAN;
    message_count INTEGER;
BEGIN
    -- Check for message_id column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'messages' AND column_name = 'message_id'
    ) INTO message_id_exists;
    
    -- Check for delivery_status column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'messages' AND column_name = 'delivery_status'
    ) INTO delivery_status_exists;
    
    SELECT COUNT(*) INTO message_count FROM messages LIMIT 1;
    
    IF message_id_exists THEN
        RAISE NOTICE '✅ Phase 2.3: message_id column exists';
    ELSE
        RAISE NOTICE '❌ Phase 2.3: message_id column missing';
    END IF;
    
    IF delivery_status_exists THEN
        RAISE NOTICE '✅ Phase 2.3: delivery_status column exists';
    ELSE
        RAISE NOTICE '❌ Phase 2.3: delivery_status column missing';
    END IF;
END $$;

-- Phase 3.1: Performance Indexes
-- ===============================================
DO $$
DECLARE
    sender_index_exists BOOLEAN;
    room_index_exists BOOLEAN;
    created_at_index_exists BOOLEAN;
    index_count INTEGER;
BEGIN
    -- Check for critical indexes on messages table
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'messages'
          AND indexname LIKE '%sender%'
    ) INTO sender_index_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'messages'
          AND indexname LIKE '%room%'
    ) INTO room_index_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'messages'
          AND indexname LIKE '%created_at%'
    ) INTO created_at_index_exists;
    
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes
    WHERE tablename = 'messages';
    
    RAISE NOTICE 'Phase 3.1: Messages table indexes:';
    IF sender_index_exists THEN
        RAISE NOTICE '  ✅ sender_id index exists';
    ELSE
        RAISE NOTICE '  ❌ sender_id index missing';
    END IF;
    
    IF room_index_exists THEN
        RAISE NOTICE '  ✅ room_id index exists';
    ELSE
        RAISE NOTICE '  ❌ room_id index missing';
    END IF;
    
    IF created_at_index_exists THEN
        RAISE NOTICE '  ✅ created_at index exists';
    ELSE
        RAISE NOTICE '  ❌ created_at index missing';
    END IF;
    
    RAISE NOTICE '  Total indexes on messages: %', index_count;
END $$;

-- Check conversation_participants indexes
DO $$
DECLARE
    user_index_exists BOOLEAN;
    conv_index_exists BOOLEAN;
    index_count INTEGER;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'conversation_participants'
          AND indexname LIKE '%user_id%'
    ) INTO user_index_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'conversation_participants'
          AND indexname LIKE '%conversation_id%'
    ) INTO conv_index_exists;
    
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes
    WHERE tablename = 'conversation_participants';
    
    RAISE NOTICE 'Phase 3.1: conversation_participants indexes:';
    IF user_index_exists THEN
        RAISE NOTICE '  ✅ user_id index exists';
    ELSE
        RAISE NOTICE '  ❌ user_id index missing';
    END IF;
    
    IF conv_index_exists THEN
        RAISE NOTICE '  ✅ conversation_id index exists';
    ELSE
        RAISE NOTICE '  ❌ conversation_id index missing';
    END IF;
    
    RAISE NOTICE '  Total indexes: %', index_count;
END $$;

-- Phase 3.3: Message Archival
-- ===============================================
DO $$
DECLARE
    archive_table_exists BOOLEAN;
    archive_count INTEGER;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'message_archives'
    ) INTO archive_table_exists;
    
    IF archive_table_exists THEN
        RAISE NOTICE '✅ Phase 3.3: message_archives table exists';
        
        SELECT COUNT(*) INTO archive_count FROM message_archives;
        RAISE NOTICE '   Archived messages: %', archive_count;
    ELSE
        RAISE NOTICE '❌ Phase 3.3: message_archives table missing';
    END IF;
END $$;

-- Summary
-- ===============================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=' || repeat('=', 78);
    RAISE NOTICE 'VALIDATION COMPLETE';
    RAISE NOTICE '=' || repeat('=', 78);
    RAISE NOTICE '';
    RAISE NOTICE 'Review the results above. All checks marked with ✅ passed.';
    RAISE NOTICE 'Items marked with ❌ need attention.';
    RAISE NOTICE '';
END $$;

