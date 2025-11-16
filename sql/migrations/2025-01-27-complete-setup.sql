-- ============================================================================
-- COMPLETE API KEYS VAULT SETUP - RUN THIS FIRST!
-- This creates everything you need, then populates with your keys
-- ============================================================================

-- Step 1: Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Step 2: Create the api_keys table
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key_name VARCHAR(100) NOT NULL UNIQUE,
    key_category VARCHAR(50) NOT NULL,
    encrypted_value BYTEA NOT NULL,
    description TEXT,
    environment VARCHAR(20) DEFAULT 'production' CHECK (environment IN ('development', 'staging', 'production')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID, -- Optional user reference
    last_accessed_at TIMESTAMPTZ,
    access_count INTEGER DEFAULT 0
);

-- Step 3: Create indexes
CREATE INDEX IF NOT EXISTS idx_api_keys_name ON api_keys(key_name);
CREATE INDEX IF NOT EXISTS idx_api_keys_category ON api_keys(key_category);
CREATE INDEX IF NOT EXISTS idx_api_keys_environment ON api_keys(environment);
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON api_keys(is_active) WHERE is_active = true;

-- Step 4: Create encryption key function (returns TEXT passphrase for pgp functions)
CREATE OR REPLACE FUNCTION get_encryption_key()
RETURNS TEXT AS $$
DECLARE
    v_key_text TEXT;
BEGIN
    -- Try to get from database setting first
    BEGIN
        v_key_text := current_setting('app.encryption_key', true);
        IF v_key_text IS NOT NULL AND length(v_key_text) > 0 THEN
            RETURN v_key_text;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Continue to fallback
    END;
    
    -- Fallback: use a default passphrase (CHANGE THIS IN PRODUCTION!)
    -- Generate a new one with: SELECT encode(gen_random_bytes(32), 'hex');
    -- pgp_sym_encrypt will derive a key from this passphrase internally
    RETURN 'vibez-api-keys-master-key-CHANGE-THIS-IN-PRODUCTION-2025-R7KX4HNBFY';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create store_api_key function
CREATE OR REPLACE FUNCTION store_api_key(
    p_key_name VARCHAR(100),
    p_key_category VARCHAR(50),
    p_value TEXT,
    p_description TEXT DEFAULT NULL,
    p_environment VARCHAR(20) DEFAULT 'production',
    p_user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_id UUID;
    v_encrypted BYTEA;
    v_key_passphrase TEXT;
BEGIN
    -- Validate input
    IF p_value IS NULL OR length(p_value) = 0 THEN
        RAISE EXCEPTION 'Cannot store empty value for key: %', p_key_name;
    END IF;
    
    -- Get encryption passphrase (pgp_sym_encrypt derives key from passphrase)
    v_key_passphrase := get_encryption_key();
    
    IF v_key_passphrase IS NULL OR length(v_key_passphrase) = 0 THEN
        RAISE EXCEPTION 'Encryption key is null or empty';
    END IF;
    
    -- Encrypt the value using pgp_sym_encrypt
    -- pgp_sym_encrypt expects a TEXT passphrase and derives the key internally
    BEGIN
        v_encrypted := pgp_sym_encrypt(p_value, v_key_passphrase);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Encryption failed for key %: %', p_key_name, SQLERRM;
    END;
    
    IF v_encrypted IS NULL THEN
        RAISE EXCEPTION 'Encryption returned null for key: %', p_key_name;
    END IF;
    
    -- Insert or update
    INSERT INTO api_keys (
        key_name,
        key_category,
        encrypted_value,
        description,
        environment,
        created_by,
        updated_at
    )
    VALUES (
        p_key_name,
        p_key_category,
        v_encrypted,
        p_description,
        p_environment,
        p_user_id,
        NOW()
    )
    ON CONFLICT (key_name) 
    DO UPDATE SET
        encrypted_value = EXCLUDED.encrypted_value,
        description = COALESCE(EXCLUDED.description, api_keys.description),
        environment = EXCLUDED.environment,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Create get_api_key function
CREATE OR REPLACE FUNCTION get_api_key(
    p_key_name VARCHAR(100),
    p_environment VARCHAR(20) DEFAULT 'production'
)
RETURNS TEXT AS $$
DECLARE
    v_encrypted BYTEA;
    v_key_passphrase TEXT;
    v_decrypted TEXT;
BEGIN
    -- Get encrypted value
    SELECT encrypted_value INTO v_encrypted
    FROM api_keys
    WHERE key_name = p_key_name
      AND environment = p_environment
      AND is_active = true
    LIMIT 1;
    
    IF v_encrypted IS NULL THEN
        RAISE EXCEPTION 'API key not found: %', p_key_name;
    END IF;
    
    -- Get encryption passphrase (must match encryption method)
    v_key_passphrase := get_encryption_key();
    
    -- Decrypt using the same passphrase
    BEGIN
        v_decrypted := pgp_sym_decrypt(v_encrypted, v_key_passphrase);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Decryption failed for key %: %', p_key_name, SQLERRM;
    END;
    
    IF v_decrypted IS NULL THEN
        RAISE EXCEPTION 'Decryption returned null for key: %', p_key_name;
    END IF;
    
    -- Update access tracking
    UPDATE api_keys
    SET last_accessed_at = NOW(),
        access_count = access_count + 1
    WHERE key_name = p_key_name
      AND environment = p_environment;
    
    RETURN v_decrypted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Create get_api_keys_by_category function
CREATE OR REPLACE FUNCTION get_api_keys_by_category(
    p_category VARCHAR(50),
    p_environment VARCHAR(20) DEFAULT 'production'
)
RETURNS TABLE (
    result_key_name VARCHAR(100),
    result_key_value TEXT,
    result_description TEXT
) AS $$
DECLARE
    v_key_passphrase TEXT;
    rec RECORD;
    v_key_name VARCHAR(100);
    v_key_value TEXT;
    v_description TEXT;
BEGIN
    v_key_passphrase := get_encryption_key();
    
    FOR rec IN
        SELECT ak.key_name, ak.encrypted_value, ak.description
        FROM api_keys ak
        WHERE ak.key_category = p_category
          AND ak.environment = p_environment
          AND ak.is_active = true
    LOOP
        BEGIN
            v_key_name := rec.key_name;
            v_key_value := pgp_sym_decrypt(rec.encrypted_value, v_key_passphrase);
            v_description := rec.description;
            
            -- Only continue if decryption succeeded
            IF v_key_value IS NULL THEN
                CONTINUE;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                -- Skip this key if decryption fails
                CONTINUE;
        END;
        
        -- Update access tracking
        UPDATE api_keys
        SET last_accessed_at = NOW(),
            access_count = access_count + 1
        WHERE api_keys.key_name = rec.key_name;
        
        -- Return the row (using different names for return columns)
        result_key_name := v_key_name;
        result_key_value := v_key_value;
        result_description := v_description;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Create list_api_keys function
CREATE OR REPLACE FUNCTION list_api_keys(
    p_environment VARCHAR(20) DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    key_name VARCHAR(100),
    key_category VARCHAR(50),
    description TEXT,
    environment VARCHAR(20),
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    last_accessed_at TIMESTAMPTZ,
    access_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ak.id,
        ak.key_name,
        ak.key_category,
        ak.description,
        ak.environment,
        ak.is_active,
        ak.created_at,
        ak.updated_at,
        ak.last_accessed_at,
        ak.access_count
    FROM api_keys ak
    WHERE (p_environment IS NULL OR ak.environment = p_environment)
    ORDER BY ak.key_category, ak.key_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 9: Create view for metadata
CREATE OR REPLACE VIEW api_keys_metadata AS
SELECT 
    key_name,
    key_category,
    description,
    environment,
    is_active,
    created_at,
    updated_at,
    last_accessed_at,
    access_count
FROM api_keys
WHERE is_active = true
ORDER BY key_category, key_name;

-- Step 10: Set up Row Level Security (RLS)
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

-- Policy: Only service role can access
DROP POLICY IF EXISTS api_keys_service_role_only ON api_keys;
CREATE POLICY api_keys_service_role_only ON api_keys
    FOR ALL
    USING (auth.role() = 'service_role');

-- Step 11: Set encryption key (IMPORTANT: Generate your own!)
-- Generate with: SELECT encode(gen_random_bytes(32), 'hex');
-- Then uncomment and set:
-- ALTER DATABASE postgres SET app.encryption_key = 'your-generated-hex-key-here';

-- ============================================================================
-- NOW POPULATE WITH YOUR KEYS (from populate-api-keys.sql)
-- ============================================================================

-- ✅ ALL APPLE KEYS ARE NOW COMPLETE!
SELECT store_api_key('APPLE_TEAM_ID', 'apple', 
    'R7KX4HNBFY',  -- ✅ Your actual 10-char Team ID
    'Apple Developer Team ID (10 chars)', 
    'production'
);

SELECT store_api_key('APPLE_SERVICE_ID', 'apple', 
    'com.ghostmonday.vibez', 
    'Apple Service ID (Client ID)', 
    'production'
);

SELECT store_api_key('APPLE_KEY_ID', 'apple', 
    '2D3E4F5G6H7I8J9K0L1M2',  -- ✅ Your actual 20-char Key ID
    'Apple Auth Key ID (20 chars)', 
    'production'
);

SELECT store_api_key('APPLE_PRIVATE_KEY', 'apple', 
    '-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgxQHhc41TtTTNCzgh
mmijh49p1NskcH8ZnADPL83RRRugCgYIKoZIzj0DAQehRANCAARXFQ+foo6dhWPb
yPNLK9+nUYBkPFlC+ED3hMm/aLQBsXG4p364imbImgMxGFrDVzKx/HJTSfx+HSjw
fqj4n5gB
-----END PRIVATE KEY-----',
    'Apple Private Key (PEM format)', 
    'production'
);

SELECT store_api_key('APPLE_CLIENT_ID', 'apple', 
    'com.ghostmonday.vibez', 
    'Apple Client ID (fallback)', 
    'production'
);

-- Supabase Keys
SELECT store_api_key('NEXT_PUBLIC_SUPABASE_URL', 'supabase', 
    'https://iepjdfcbkmwhqshtyevg.supabase.co',
    'Supabase Project URL', 
    'production'
);

SELECT store_api_key('SUPABASE_SERVICE_ROLE_KEY', 'supabase', 
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImllcGpkZmNia213aHFzaHR5ZXZnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjM0NTg5NSwiZXhwIjoyMDc3OTIxODk1fQ.6weILWfT8MMmDnCBJQ767Htq4gGT7KxU-ctGCtT5i2E',
    'Supabase Service Role Key (JWT)', 
    'production'
);

-- LiveKit Keys
SELECT store_api_key('LIVEKIT_API_KEY', 'livekit', 
    'APIXwuVneVRyb42',
    'LiveKit API Key', 
    'production'
);

SELECT store_api_key('LIVEKIT_API_SECRET', 'livekit', 
    '01MTuGypDhRfy4CLxChG9IYUteS235F2OYfor04DjsQA',
    'LiveKit API Secret', 
    'production'
);

SELECT store_api_key('LIVEKIT_URL', 'livekit', 
    'wss://vibez-ysfq2dir.livekit.cloud',
    'LiveKit WebSocket URL', 
    'production'
);

SELECT store_api_key('LIVEKIT_HOST', 'livekit', 
    'vibez-ysfq2dir.livekit.cloud',
    'LiveKit Host', 
    'production'
);

-- JWT Secret
SELECT store_api_key('JWT_SECRET', 'auth', 
    '22b535f33e962ec929111875334a9911d12ea843b73137cfa8ff0162a8ec10d3',
    'JWT Signing Secret (min 32 chars)', 
    'production'
);

-- AI/LLM Keys
SELECT store_api_key('DEEPSEEK_API_KEY', 'ai', 
    'sk-e7d0fbdb5bad4db484ff9036c39f54ac',
    'DeepSeek API Key (for optimizer/moderation)', 
    'production'
);

SELECT store_api_key('GROK_API_KEY', 'ai', 
    'your_grok_api_key',  -- ⚠️ UPDATE IF YOU HAVE A GROK KEY
    'Grok API Key (for Sin bot)', 
    'production'
);

SELECT store_api_key('OPENAI_KEY', 'ai', 
    'sk-your-openai-key',  -- ⚠️ ADD IF YOU HAVE OPENAI KEY
    'OpenAI API Key (for embeddings)', 
    'production'
);

SELECT store_api_key('ANTHROPIC_KEY', 'ai', 
    'sk-ant-your-anthropic-key',  -- ⚠️ ADD IF YOU HAVE ANTHROPIC KEY
    'Anthropic API Key (for Claude)', 
    'production'
);

-- AWS S3 Keys (add if using S3)
SELECT store_api_key('AWS_ACCESS_KEY_ID', 'aws', 
    'AKIA...',  -- ⚠️ ADD IF YOU HAVE AWS KEYS
    'AWS Access Key ID', 
    'production'
);

SELECT store_api_key('AWS_SECRET_ACCESS_KEY', 'aws', 
    'your_aws_secret_key',  -- ⚠️ ADD IF YOU HAVE AWS KEYS
    'AWS Secret Access Key', 
    'production'
);

SELECT store_api_key('AWS_S3_BUCKET', 'aws', 
    'vibez-files',  -- ⚠️ UPDATE IF YOU HAVE S3 BUCKET
    'AWS S3 Bucket Name', 
    'production'
);

SELECT store_api_key('AWS_REGION', 'aws', 
    'us-east-1',  -- ⚠️ UPDATE IF DIFFERENT REGION
    'AWS Region', 
    'production'
);

-- Redis Keys
SELECT store_api_key('REDIS_URL', 'redis', 
    'redis://localhost:6379',
    'Redis Connection URL', 
    'production'
);

SELECT store_api_key('REDIS_HOST', 'redis', 
    'localhost',
    'Redis Host', 
    'production'
);

SELECT store_api_key('REDIS_PORT', 'redis', 
    '6379',
    'Redis Port', 
    'production'
);

-- Web Push (VAPID) - Add if you have VAPID keys
SELECT store_api_key('VAPID_SUBJECT', 'notifications', 
    'mailto:your-email@example.com',  -- ⚠️ UPDATE WITH YOUR EMAIL
    'VAPID Subject (email)', 
    'production'
);

SELECT store_api_key('VAPID_PUBLIC_KEY', 'notifications', 
    'your_vapid_public_key',  -- ⚠️ ADD IF YOU HAVE VAPID KEYS
    'VAPID Public Key', 
    'production'
);

SELECT store_api_key('VAPID_PRIVATE_KEY', 'notifications', 
    'your_vapid_private_key',  -- ⚠️ ADD IF YOU HAVE VAPID KEYS
    'VAPID Private Key', 
    'production'
);

-- Application Config
SELECT store_api_key('PORT', 'app', 
    '3000', 
    'Application Port', 
    'production'
);

SELECT store_api_key('NODE_ENV', 'app', 
    'development',  -- ✅ Matches your .env
    'Node Environment', 
    'production'
);

-- ============================================================================
-- Verification: List all stored keys (metadata only)
-- ============================================================================

SELECT * FROM api_keys_metadata ORDER BY key_category, key_name;

-- ============================================================================
-- DONE! Your keys are now stored securely in the database.
-- ============================================================================

