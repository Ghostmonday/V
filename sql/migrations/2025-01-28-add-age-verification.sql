-- ===============================================
-- Migration: Add Age Verification Support
-- Purpose: Add age_verified column to users table for 18+ gate
-- ===============================================

BEGIN;

-- Add age_verified column to users table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'age_verified'
    ) THEN
        ALTER TABLE users ADD COLUMN age_verified BOOLEAN DEFAULT false NOT NULL;
        RAISE NOTICE 'Added age_verified column to users table';
    ELSE
        RAISE NOTICE 'Column users.age_verified already exists';
    END IF;
END $$;

-- Add index for efficient queries
CREATE INDEX IF NOT EXISTS idx_users_age_verified ON users(age_verified) WHERE age_verified = true;

COMMIT;

