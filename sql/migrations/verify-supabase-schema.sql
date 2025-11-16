-- ===============================================
-- Supabase Schema Verification Script
-- Purpose: Check if all required tables/columns exist
-- Run this in Supabase SQL Editor to verify setup
-- ===============================================

-- Check if users table exists and has required columns
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
        RAISE EXCEPTION 'Table "users" does not exist';
    END IF;
    
    -- Check for subscription column (new requirement)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'subscription'
    ) THEN
        RAISE WARNING 'Column "users.subscription" does not exist - subscription service will fail';
    END IF;
    
    -- Check for password_hash column (security requirement)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'password_hash'
    ) THEN
        RAISE WARNING 'Column "users.password_hash" does not exist - password hashing will fail';
    END IF;
END $$;

-- Check if usage_stats table exists (new requirement)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'usage_stats') THEN
        RAISE EXCEPTION 'Table "usage_stats" does not exist - usage tracking will fail';
    END IF;
    
    -- Verify required columns
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'usage_stats' AND column_name = 'user_id'
    ) THEN
        RAISE EXCEPTION 'Column "usage_stats.user_id" does not exist';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'usage_stats' AND column_name = 'event_type'
    ) THEN
        RAISE EXCEPTION 'Column "usage_stats.event_type" does not exist';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'usage_stats' AND column_name = 'metadata'
    ) THEN
        RAISE EXCEPTION 'Column "usage_stats.metadata" does not exist';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'usage_stats' AND column_name = 'ts'
    ) THEN
        RAISE EXCEPTION 'Column "usage_stats.ts" does not exist';
    END IF;
END $$;

-- Check if iap_receipts table exists and has required columns
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'iap_receipts') THEN
        RAISE EXCEPTION 'Table "iap_receipts" does not exist - IAP verification will fail';
    END IF;
    
    -- Check for new columns we added
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'iap_receipts' AND column_name = 'transaction_id'
    ) THEN
        RAISE WARNING 'Column "iap_receipts.transaction_id" does not exist - IAP service may fail';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'iap_receipts' AND column_name = 'product_id'
    ) THEN
        RAISE WARNING 'Column "iap_receipts.product_id" does not exist - IAP service may fail';
    END IF;
END $$;

-- Check for P0 features tables
DO $$
BEGIN
    -- Threads table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'threads') THEN
        RAISE WARNING 'Table "threads" does not exist - thread features will fail';
    END IF;
    
    -- Edit history table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'edit_history') THEN
        RAISE WARNING 'Table "edit_history" does not exist - edit history will fail';
    END IF;
    
    -- Message search index (materialized view)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'message_search_index'
    ) THEN
        RAISE WARNING 'Materialized view "message_search_index" does not exist - search will fail';
    END IF;
    
    -- Bot endpoints table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bot_endpoints') THEN
        RAISE WARNING 'Table "bot_endpoints" does not exist - bot API will fail';
    END IF;
END $$;

-- Check for core tables
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rooms') THEN
        RAISE EXCEPTION 'Table "rooms" does not exist';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'messages') THEN
        RAISE EXCEPTION 'Table "messages" does not exist';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'files') THEN
        RAISE WARNING 'Table "files" does not exist - file storage will fail';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'config') THEN
        RAISE WARNING 'Table "config" does not exist - config service will fail';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'telemetry') THEN
        RAISE WARNING 'Table "telemetry" does not exist - telemetry service will fail';
    END IF;
END $$;

-- Summary report
SELECT 
    'Schema Verification Complete' as status,
    COUNT(*) FILTER (WHERE table_type = 'BASE TABLE') as total_tables,
    COUNT(*) FILTER (WHERE table_name IN ('users', 'rooms', 'messages', 'usage_stats', 'iap_receipts')) as critical_tables
FROM information_schema.tables
WHERE table_schema = 'public';

