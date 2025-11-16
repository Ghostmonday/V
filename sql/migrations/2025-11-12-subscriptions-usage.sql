-- ===============================================
-- Migration: Monetization Subscriptions & Usage
-- Date: 2025-11-12
-- Purpose: Add tables for subscription-based monetization and usage tracking
-- ===============================================

BEGIN;

-- ===============================================
-- 1. Create monetization_subscriptions table
-- ===============================================
CREATE TABLE IF NOT EXISTS monetization_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan TEXT NOT NULL CHECK (plan IN ('free', 'pro_monthly', 'pro_annual', 'enterprise')),
    status TEXT NOT NULL CHECK (status IN ('active', 'cancelled', 'expired', 'trial', 'pending')),
    renewal_date TIMESTAMP WITH TIME ZONE,
    entitlements JSONB DEFAULT '{}'::jsonb,
    transaction_id TEXT, -- App Store transaction ID
    product_id TEXT, -- StoreKit product ID
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_monetization_subscriptions_user_id ON monetization_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_monetization_subscriptions_status ON monetization_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_monetization_subscriptions_plan ON monetization_subscriptions(plan);
CREATE INDEX IF NOT EXISTS idx_monetization_subscriptions_renewal_date ON monetization_subscriptions(renewal_date);
CREATE INDEX IF NOT EXISTS idx_monetization_subscriptions_transaction_id ON monetization_subscriptions(transaction_id);

-- Enable Row Level Security
ALTER TABLE monetization_subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own subscriptions
CREATE POLICY "Users can view their own subscriptions"
    ON monetization_subscriptions
    FOR SELECT
    USING (user_id = auth.uid());

-- RLS Policy: Users can update their own subscriptions (for restore purchases)
CREATE POLICY "Users can update their own subscriptions"
    ON monetization_subscriptions
    FOR UPDATE
    USING (user_id = auth.uid());

-- RLS Policy: Service role can insert/update (for webhooks)
CREATE POLICY "Service role can manage subscriptions"
    ON monetization_subscriptions
    FOR ALL
    USING (auth.role() = 'service_role');

-- ===============================================
-- 2. Create usage table for metering
-- ===============================================
CREATE TABLE IF NOT EXISTS usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ai_calls INT DEFAULT 0,
    voice_minutes INT DEFAULT 0,
    storage_bytes BIGINT DEFAULT 0,
    period_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT DATE_TRUNC('month', NOW()),
    period_end TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (DATE_TRUNC('month', NOW()) + INTERVAL '1 month'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_usage_user_id ON usage(user_id);
CREATE INDEX IF NOT EXISTS idx_usage_period ON usage(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_usage_user_period ON usage(user_id, period_start, period_end);

-- Enable Row Level Security
ALTER TABLE usage ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own usage
CREATE POLICY "Users can view their own usage"
    ON usage
    FOR SELECT
    USING (user_id = auth.uid());

-- RLS Policy: Service role can manage usage (for backend updates)
CREATE POLICY "Service role can manage usage"
    ON usage
    FOR ALL
    USING (auth.role() = 'service_role');

-- ===============================================
-- 3. Create function to get or create usage record
-- ===============================================
CREATE OR REPLACE FUNCTION get_or_create_usage(p_user_id UUID, p_period_start TIMESTAMP WITH TIME ZONE DEFAULT DATE_TRUNC('month', NOW()))
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_usage_id UUID;
    v_period_end TIMESTAMP WITH TIME ZONE;
BEGIN
    v_period_end := p_period_start + INTERVAL '1 month';
    
    -- Try to get existing usage record
    SELECT id INTO v_usage_id
    FROM usage
    WHERE user_id = p_user_id
      AND period_start = p_period_start
      AND period_end = v_period_end;
    
    -- Create if doesn't exist
    IF v_usage_id IS NULL THEN
        INSERT INTO usage (user_id, period_start, period_end)
        VALUES (p_user_id, p_period_start, v_period_end)
        RETURNING id INTO v_usage_id;
    END IF;
    
    RETURN v_usage_id;
END;
$$;

-- ===============================================
-- 4. Create function to increment usage
-- ===============================================
CREATE OR REPLACE FUNCTION increment_usage(
    p_user_id UUID,
    p_type TEXT, -- 'ai_calls', 'voice_minutes', 'storage_bytes'
    p_amount NUMERIC DEFAULT 1
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_usage_id UUID;
BEGIN
    -- Get or create usage record for current period
    v_usage_id := get_or_create_usage(p_user_id);
    
    -- Increment the appropriate field
    CASE p_type
        WHEN 'ai_calls' THEN
            UPDATE usage SET ai_calls = ai_calls + p_amount::INT, updated_at = NOW() WHERE id = v_usage_id;
        WHEN 'voice_minutes' THEN
            UPDATE usage SET voice_minutes = voice_minutes + p_amount::INT, updated_at = NOW() WHERE id = v_usage_id;
        WHEN 'storage_bytes' THEN
            UPDATE usage SET storage_bytes = storage_bytes + p_amount::BIGINT, updated_at = NOW() WHERE id = v_usage_id;
        ELSE
            RAISE EXCEPTION 'Invalid usage type: %', p_type;
    END CASE;
END;
$$;

COMMIT;

-- ===============================================
-- Validation Queries
-- ===============================================
-- Run these in Supabase SQL editor to validate:

-- 1. Check tables exist
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema = 'public' 
-- AND table_name IN ('monetization_subscriptions', 'usage');

-- 2. Check RLS is enabled
-- SELECT tablename, rowsecurity FROM pg_tables 
-- WHERE schemaname = 'public' 
-- AND tablename IN ('monetization_subscriptions', 'usage');

-- 3. Test insert (as authenticated user - replace with your user_id)
-- INSERT INTO monetization_subscriptions (user_id, plan, status)
-- VALUES (auth.uid(), 'pro_monthly', 'active')
-- RETURNING *;

-- 4. Test usage increment function
-- SELECT increment_usage(auth.uid(), 'ai_calls', 1);
-- SELECT * FROM usage WHERE user_id = auth.uid();

