-- ===============================================
-- Migration: Add Subscription & Usage Support
-- Purpose: Add missing columns/tables for monetization features
-- Run this AFTER verifying schema with verify-supabase-schema.sql
-- ===============================================

BEGIN;

-- ===============================================
-- 1. Add subscription column to users table
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
-- 2. Add password_hash column to users table (if missing)
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
-- 3. Create usage_stats table (if missing)
-- ===============================================
CREATE TABLE IF NOT EXISTS usage_stats (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL, -- Changed from INT to TEXT to support UUID users
    event_type TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Add index for efficient queries
CREATE INDEX IF NOT EXISTS idx_usage_stats_user_event ON usage_stats(user_id, event_type);
CREATE INDEX IF NOT EXISTS idx_usage_stats_ts ON usage_stats(ts DESC);
CREATE INDEX IF NOT EXISTS idx_usage_stats_user_ts ON usage_stats(user_id, ts DESC);

-- ===============================================
-- 4. Update iap_receipts table (add missing columns)
-- ===============================================
DO $$
BEGIN
    -- Add transaction_id if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'iap_receipts' AND column_name = 'transaction_id'
    ) THEN
        ALTER TABLE iap_receipts ADD COLUMN transaction_id TEXT;
        RAISE NOTICE 'Added transaction_id column to iap_receipts table';
    END IF;
    
    -- Add product_id if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'iap_receipts' AND column_name = 'product_id'
    ) THEN
        ALTER TABLE iap_receipts ADD COLUMN product_id TEXT;
        RAISE NOTICE 'Added product_id column to iap_receipts table';
    END IF;
    
    -- Add status column if missing (for better tracking)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'iap_receipts' AND column_name = 'status'
    ) THEN
        ALTER TABLE iap_receipts ADD COLUMN status TEXT DEFAULT 'pending';
        RAISE NOTICE 'Added status column to iap_receipts table';
    END IF;
    
    -- Add purchase_date if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'iap_receipts' AND column_name = 'purchase_date'
    ) THEN
        ALTER TABLE iap_receipts ADD COLUMN purchase_date TIMESTAMPTZ;
        RAISE NOTICE 'Added purchase_date column to iap_receipts table';
    END IF;
END $$;

-- ===============================================
-- 5. Ensure user_id columns are compatible
-- ===============================================
-- Note: If your users table uses UUID, you may need to adjust foreign key types
-- This migration assumes TEXT for user_id to support both UUID and integer IDs

-- ===============================================
-- 6. Set default subscription for existing users
-- ===============================================
UPDATE users SET subscription = 'free' WHERE subscription IS NULL;

COMMIT;

-- Verification query
SELECT 
    'Migration Complete' as status,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'subscription') as has_subscription_column,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'password_hash') as has_password_hash,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'usage_stats') as has_usage_stats_table,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'iap_receipts' AND column_name = 'transaction_id') as has_transaction_id,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'iap_receipts' AND column_name = 'product_id') as has_product_id;

