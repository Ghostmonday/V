-- ===============================================
-- Migration: Add Remaining Missing Tables & Columns
-- Purpose: Complete schema setup after P0 features migration
-- Run this AFTER 09_p0_features_fixed.sql
-- ===============================================

BEGIN;

-- ===============================================
-- 1. Create config table (if missing)
-- ===============================================
CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value JSONB
);

-- ===============================================
-- 2. Create files table (if missing)
-- ===============================================
CREATE TABLE IF NOT EXISTS files (
    id SERIAL PRIMARY KEY,
    url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    file_size BIGINT,
    mime_type TEXT,
    uploaded_by TEXT -- user_id (TEXT to support UUID or INT)
);

CREATE INDEX IF NOT EXISTS idx_files_uploaded_by ON files(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_files_created_at ON files(created_at DESC);

-- ===============================================
-- 3. Add subscription column to users (if missing)
-- ===============================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'subscription'
    ) THEN
        ALTER TABLE users ADD COLUMN subscription TEXT DEFAULT 'free';
        RAISE NOTICE 'Added subscription column to users table';
    ELSE
        RAISE NOTICE 'Column users.subscription already exists';
    END IF;
END $$;

-- ===============================================
-- 4. Add password_hash column to users (if missing)
-- ===============================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'password_hash'
    ) THEN
        ALTER TABLE users ADD COLUMN password_hash TEXT;
        RAISE NOTICE 'Added password_hash column to users table';
    ELSE
        RAISE NOTICE 'Column users.password_hash already exists';
    END IF;
END $$;

-- ===============================================
-- 5. Ensure usage_stats table exists with metadata column
-- ===============================================
-- Check if table exists first
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'usage_stats') THEN
        -- Create table if it doesn't exist
        CREATE TABLE usage_stats (
            id SERIAL PRIMARY KEY,
            user_id TEXT NOT NULL, -- TEXT to support both UUID and INT user IDs
            event_type TEXT NOT NULL,
            metadata JSONB DEFAULT '{}'::jsonb,
            ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
        );
        RAISE NOTICE 'Created usage_stats table';
    ELSE
        -- Table exists, check and add missing columns
        -- Add metadata column if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'usage_stats' AND column_name = 'metadata'
        ) THEN
            ALTER TABLE usage_stats ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
            RAISE NOTICE 'Added metadata column to usage_stats table';
        END IF;
        
        -- Add ts column if missing (table might use 'timestamp' instead)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'usage_stats' AND column_name = 'ts'
        ) THEN
            -- Check if 'timestamp' column exists
            IF EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'usage_stats' AND column_name = 'timestamp'
            ) THEN
                -- Rename timestamp to ts for consistency
                ALTER TABLE usage_stats RENAME COLUMN timestamp TO ts;
                RAISE NOTICE 'Renamed timestamp column to ts in usage_stats table';
            ELSE
                -- Add ts column
                ALTER TABLE usage_stats ADD COLUMN ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
                RAISE NOTICE 'Added ts column to usage_stats table';
            END IF;
        END IF;
        
        -- Ensure user_id is TEXT (might be INT)
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'usage_stats' 
            AND column_name = 'user_id' 
            AND data_type = 'integer'
        ) THEN
            -- Convert INT to TEXT (requires data migration)
            ALTER TABLE usage_stats ALTER COLUMN user_id TYPE TEXT USING user_id::TEXT;
            RAISE NOTICE 'Converted user_id column to TEXT in usage_stats table';
        END IF;
    END IF;
END $$;

-- Create indexes for usage_stats (only if ts column exists)
DO $$
BEGIN
    -- Only create indexes if ts column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'usage_stats' AND column_name = 'ts'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_usage_stats_user_event ON usage_stats(user_id, event_type);
        CREATE INDEX IF NOT EXISTS idx_usage_stats_ts ON usage_stats(ts DESC);
        CREATE INDEX IF NOT EXISTS idx_usage_stats_user_ts ON usage_stats(user_id, ts DESC);
        RAISE NOTICE 'Created indexes on usage_stats table';
    ELSE
        RAISE WARNING 'Cannot create indexes: ts column does not exist in usage_stats';
    END IF;
END $$;

-- ===============================================
-- 6. Set default subscription for existing users
-- ===============================================
UPDATE users SET subscription = 'free' WHERE subscription IS NULL;

COMMIT;

-- ===============================================
-- Verification Query
-- ===============================================
SELECT 
    'Remaining Tables Migration Complete' as status,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'config') as has_config_table,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'files') as has_files_table,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'subscription') as has_subscription_column,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'password_hash') as has_password_hash,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'usage_stats' AND column_name = 'metadata') as has_usage_stats_metadata;

