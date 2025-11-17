-- ============================================================================
-- API Keys Vault System
-- Secure storage and retrieval of all API keys and secrets
-- Uses pgcrypto for encryption at rest
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- API Keys Table
-- ============================================================================

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
    created_by UUID, -- Made optional (no FK constraint if users table doesn't exist)
    last_accessed_at TIMESTAMPTZ,
    access_count INTEGER DEFAULT 0
);

-- Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_api_keys_name ON api_keys(key_name);
CREATE INDEX IF NOT EXISTS idx_api_keys_category ON api_keys(key_category);
CREATE INDEX IF NOT EXISTS idx_api_keys_environment ON api_keys(environment);
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON api_keys(is_active) WHERE is_active = true;

-- ============================================================================
-- Encryption Key Management
-- ============================================================================

-- Master encryption key (store this securely, rotate periodically)
-- Generate with: SELECT gen_random_bytes(32);
-- Store in Supabase Vault or environment variable
DO $$
DECLARE
    master_key TEXT;
BEGIN
    -- Check if master key exists in vault
    -- If not, generate one (you should set this manually via Supabase Vault)
    -- For now, we'll use a function that retrieves from vault
    NULL;
END $$;

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Function to get encryption key (from vault or env)
-- In production, use Supabase Vault: SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'api_keys_master_key';
CREATE OR REPLACE FUNCTION get_encryption_key()
RETURNS BYTEA AS $$
BEGIN
    -- Option 1: Use Supabase Vault (recommended)
    -- RETURN (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'api_keys_master_key' LIMIT 1);
    
    -- Option 2: Use environment variable (fallback)
    -- This should be set via: ALTER DATABASE postgres SET app.encryption_key = 'your-32-byte-key';
    RETURN decode(current_setting('app.encryption_key', true), 'hex');
EXCEPTION
    WHEN OTHERS THEN
        -- Fallback: generate from a known seed (NOT SECURE - use vault instead)
        RETURN digest('vibez-api-keys-master-key-change-this-in-production', 'sha256');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Core Functions: Store and Retrieve Keys
-- ============================================================================

-- Function to store/update an API key
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
    v_encryption_key BYTEA;
BEGIN
    -- Get encryption key
    v_encryption_key := get_encryption_key();
    
    -- Encrypt the value
    v_encrypted := pgp_sym_encrypt(p_value, encode(v_encryption_key, 'base64'));
    
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

-- Function to retrieve an API key (decrypted)
CREATE OR REPLACE FUNCTION get_api_key(
    p_key_name VARCHAR(100),
    p_environment VARCHAR(20) DEFAULT 'production'
)
RETURNS TEXT AS $$
DECLARE
    v_encrypted BYTEA;
    v_encryption_key BYTEA;
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
    
    -- Get encryption key
    v_encryption_key := get_encryption_key();
    
    -- Decrypt
    v_decrypted := pgp_sym_decrypt(v_encrypted, encode(v_encryption_key, 'base64'));
    
    -- Update access tracking
    UPDATE api_keys
    SET last_accessed_at = NOW(),
        access_count = access_count + 1
    WHERE key_name = p_key_name
      AND environment = p_environment;
    
    RETURN v_decrypted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get multiple keys by category
CREATE OR REPLACE FUNCTION get_api_keys_by_category(
    p_category VARCHAR(50),
    p_environment VARCHAR(20) DEFAULT 'production'
)
RETURNS TABLE (
    key_name VARCHAR(100),
    key_value TEXT,
    description TEXT
) AS $$
DECLARE
    v_encryption_key BYTEA;
    rec RECORD;
BEGIN
    v_encryption_key := get_encryption_key();
    
    FOR rec IN
        SELECT key_name, encrypted_value, description
        FROM api_keys
        WHERE key_category = p_category
          AND environment = p_environment
          AND is_active = true
    LOOP
        key_name := rec.key_name;
        key_value := pgp_sym_decrypt(rec.encrypted_value, encode(v_encryption_key, 'base64'));
        description := rec.description;
        
        -- Update access tracking
        UPDATE api_keys
        SET last_accessed_at = NOW(),
            access_count = access_count + 1
        WHERE key_name = rec.key_name;
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to list all keys (without values, for admin)
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

-- Function to deactivate a key
CREATE OR REPLACE FUNCTION deactivate_api_key(
    p_key_name VARCHAR(100),
    p_environment VARCHAR(20) DEFAULT 'production'
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE api_keys
    SET is_active = false,
        updated_at = NOW()
    WHERE key_name = p_key_name
      AND environment = p_environment;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Row Level Security (RLS)
-- ============================================================================

ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

-- Policy: Only service role can access (backend only)
CREATE POLICY api_keys_service_role_only ON api_keys
    FOR ALL
    USING (auth.role() = 'service_role');

-- Policy: Deny all other access
CREATE POLICY api_keys_deny_all ON api_keys
    FOR ALL
    USING (false);

-- ============================================================================
-- Initial Data: Insert All Required Keys
-- ============================================================================

-- Apple Sign-In Keys
SELECT store_api_key('APPLE_TEAM_ID', 'apple', 'YOUR_10_CHARACTER_TEAM_ID', 'Apple Developer Team ID (10 chars)', 'production');
SELECT store_api_key('APPLE_SERVICE_ID', 'apple', 'com.ghostmonday.vibez', 'Apple Service ID (Client ID)', 'production');
SELECT store_api_key('APPLE_KEY_ID', 'apple', 'YOUR_20_CHARACTER_KEY_ID', 'Apple Auth Key ID (20 chars)', 'production');
SELECT store_api_key('APPLE_PRIVATE_KEY', 'apple', '-----BEGIN PRIVATE KEY-----\nYOUR_KEY_CONTENT_HERE\n-----END PRIVATE KEY-----', 'Apple Private Key (PEM format)', 'production');
SELECT store_api_key('APPLE_CLIENT_ID', 'apple', 'com.ghostmonday.vibez', 'Apple Client ID (fallback)', 'production');

-- Supabase Keys
SELECT store_api_key('NEXT_PUBLIC_SUPABASE_URL', 'supabase', 'https://your-project.supabase.co', 'Supabase Project URL', 'production');
SELECT store_api_key('SUPABASE_SERVICE_ROLE_KEY', 'supabase', 'your_service_role_key_here', 'Supabase Service Role Key (JWT)', 'production');

-- LiveKit Keys
SELECT store_api_key('LIVEKIT_API_KEY', 'livekit', 'your_livekit_api_key', 'LiveKit API Key', 'production');
SELECT store_api_key('LIVEKIT_API_SECRET', 'livekit', 'your_livekit_api_secret', 'LiveKit API Secret', 'production');
SELECT store_api_key('LIVEKIT_URL', 'livekit', 'wss://your-livekit-server.com', 'LiveKit WebSocket URL', 'production');
SELECT store_api_key('LIVEKIT_HOST', 'livekit', 'your-livekit-server.com', 'LiveKit Host', 'production');

-- JWT Secret
SELECT store_api_key('JWT_SECRET', 'auth', 'your_random_secret_key_min_32_chars', 'JWT Signing Secret (min 32 chars)', 'production');

-- AI/LLM Keys
SELECT store_api_key('DEEPSEEK_API_KEY', 'ai', 'sk-your-deepseek-key', 'DeepSeek API Key (for optimizer/moderation)', 'production');
SELECT store_api_key('GROK_API_KEY', 'ai', 'your_grok_api_key', 'Grok API Key (for Sin bot)', 'production');
SELECT store_api_key('ANTHROPIC_KEY', 'ai', 'sk-ant-your-anthropic-key', 'Anthropic API Key (for Claude)', 'production');

-- AWS S3 Keys
SELECT store_api_key('AWS_ACCESS_KEY_ID', 'aws', 'AKIA...', 'AWS Access Key ID', 'production');
SELECT store_api_key('AWS_SECRET_ACCESS_KEY', 'aws', 'your_aws_secret_key', 'AWS Secret Access Key', 'production');
SELECT store_api_key('AWS_S3_BUCKET', 'aws', 'vibez-files', 'AWS S3 Bucket Name', 'production');
SELECT store_api_key('AWS_REGION', 'aws', 'us-east-1', 'AWS Region', 'production');

-- Redis Keys
SELECT store_api_key('REDIS_URL', 'redis', 'redis://localhost:6379', 'Redis Connection URL', 'production');
SELECT store_api_key('REDIS_HOST', 'redis', 'localhost', 'Redis Host', 'production');
SELECT store_api_key('REDIS_PORT', 'redis', '6379', 'Redis Port', 'production');

-- Web Push (VAPID)
SELECT store_api_key('VAPID_SUBJECT', 'notifications', 'mailto:your-email@example.com', 'VAPID Subject (email)', 'production');
SELECT store_api_key('VAPID_PUBLIC_KEY', 'notifications', 'your_vapid_public_key', 'VAPID Public Key', 'production');
SELECT store_api_key('VAPID_PRIVATE_KEY', 'notifications', 'your_vapid_private_key', 'VAPID Private Key', 'production');

-- Application Config
SELECT store_api_key('PORT', 'app', '3000', 'Application Port', 'production');
SELECT store_api_key('NODE_ENV', 'app', 'production', 'Node Environment', 'production');

-- ============================================================================
-- Convenience Views (for easy access)
-- ============================================================================

-- View: All active keys by category (metadata only, no values)
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

-- ============================================================================
-- Usage Examples
-- ============================================================================

/*
-- Store a key:
SELECT store_api_key('MY_API_KEY', 'category', 'secret-value', 'Description');

-- Retrieve a key:
SELECT get_api_key('APPLE_TEAM_ID', 'production');

-- Get all keys in a category:
SELECT * FROM get_api_keys_by_category('apple', 'production');

-- List all keys (metadata):
SELECT * FROM list_api_keys('production');

-- Deactivate a key:
SELECT deactivate_api_key('OLD_API_KEY', 'production');
*/

-- ============================================================================
-- Security Notes
-- ============================================================================

/*
IMPORTANT SECURITY CONSIDERATIONS:

1. **Master Encryption Key**:
   - Store in Supabase Vault (recommended)
   - Or set via: ALTER DATABASE postgres SET app.encryption_key = 'hex-encoded-32-byte-key';
   - Generate with: SELECT encode(gen_random_bytes(32), 'hex');

2. **Access Control**:
   - Only service_role can access keys (RLS enforced)
   - Never expose get_api_key() to client-side code
   - Use only in backend/server-side functions

3. **Key Rotation**:
   - Rotate master key periodically
   - Re-encrypt all keys after rotation
   - Deactivate old keys before removing

4. **Audit Trail**:
   - access_count and last_accessed_at track usage
   - Monitor for unusual access patterns

5. **Environment Separation**:
   - Use different keys for dev/staging/prod
   - Never mix environments

6. **Backup**:
   - Backup encrypted values regularly
   - Store master key securely (separate from database)
*/

