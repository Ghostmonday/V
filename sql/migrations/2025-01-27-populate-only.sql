-- ============================================================================
-- POPULATE API KEYS - Run this to add/update keys
-- Assumes the vault system is already set up (table + functions exist)
-- ============================================================================

-- ✅ ALL APPLE KEYS COMPLETE!
SELECT store_api_key('APPLE_TEAM_ID', 'apple', 
    'YOUR_10_CHAR_TEAM_ID',  -- ⚠️ REPLACE WITH YOUR ACTUAL TEAM ID
    'Apple Developer Team ID (10 chars)', 
    'production'
);

SELECT store_api_key('APPLE_SERVICE_ID', 'apple', 
    'com.ghostmonday.vibez', 
    'Apple Service ID (Client ID)', 
    'production'
);

SELECT store_api_key('APPLE_KEY_ID', 'apple', 
    'YOUR_20_CHAR_KEY_ID',  -- ⚠️ REPLACE WITH YOUR ACTUAL KEY ID
    'Apple Auth Key ID (20 chars)', 
    'production'
);

SELECT store_api_key('APPLE_PRIVATE_KEY', 'apple', 
    '-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_CONTENT_HERE
-----END PRIVATE KEY-----',  -- ⚠️ REPLACE WITH YOUR ACTUAL PRIVATE KEY
    'Apple Private Key (PEM format)', 
    'production'
);

SELECT store_api_key('APPLE_CLIENT_ID', 'apple', 
    'com.ghostmonday.vibez', 
    'Apple Client ID (fallback)', 
    'production'
);

-- ============================================================================
-- Supabase Keys
-- ============================================================================

SELECT store_api_key('NEXT_PUBLIC_SUPABASE_URL', 'supabase', 
    'https://your-project.supabase.co',  -- ⚠️ REPLACE WITH YOUR ACTUAL URL
    'Supabase Project URL', 
    'production'
);

SELECT store_api_key('SUPABASE_SERVICE_ROLE_KEY', 'supabase', 
    'YOUR_SUPABASE_SERVICE_ROLE_KEY_HERE',  -- ⚠️ REPLACE WITH YOUR ACTUAL KEY
    'Supabase Service Role Key (JWT)', 
    'production'
);

-- ============================================================================
-- LiveKit Keys
-- ============================================================================

SELECT store_api_key('LIVEKIT_API_KEY', 'livekit', 
    'YOUR_LIVEKIT_API_KEY',  -- ⚠️ REPLACE WITH YOUR ACTUAL KEY
    'LiveKit API Key', 
    'production'
);

SELECT store_api_key('LIVEKIT_API_SECRET', 'livekit', 
    'YOUR_LIVEKIT_API_SECRET',  -- ⚠️ REPLACE WITH YOUR ACTUAL SECRET
    'LiveKit API Secret', 
    'production'
);

SELECT store_api_key('LIVEKIT_URL', 'livekit', 
    'wss://your-livekit-server.livekit.cloud',  -- ⚠️ REPLACE WITH YOUR ACTUAL URL
    'LiveKit WebSocket URL', 
    'production'
);

SELECT store_api_key('LIVEKIT_HOST', 'livekit', 
    'your-livekit-server.livekit.cloud',  -- ⚠️ REPLACE WITH YOUR ACTUAL HOST
    'LiveKit Host', 
    'production'
);

-- ============================================================================
-- JWT Secret
-- ============================================================================

SELECT store_api_key('JWT_SECRET', 'auth', 
    'YOUR_JWT_SECRET_MIN_32_CHARS',  -- ⚠️ REPLACE WITH YOUR ACTUAL SECRET
    'JWT Signing Secret (min 32 chars)', 
    'production'
);

-- ============================================================================
-- AI/LLM Keys
-- ============================================================================

SELECT store_api_key('DEEPSEEK_API_KEY', 'ai', 
    'sk-your-deepseek-key',  -- ⚠️ REPLACE WITH YOUR ACTUAL KEY
    'DeepSeek API Key (for optimizer/moderation)', 
    'production'
);

SELECT store_api_key('GROK_API_KEY', 'ai', 
    'your_grok_api_key',  -- ⚠️ UPDATE IF YOU HAVE A GROK KEY
    'Grok API Key (for Sin bot)', 
    'production'
);


SELECT store_api_key('ANTHROPIC_KEY', 'ai', 
    'sk-ant-your-anthropic-key',  -- ⚠️ ADD IF YOU HAVE ANTHROPIC KEY
    'Anthropic API Key (for Claude)', 
    'production'
);

-- ============================================================================
-- AWS S3 Keys (add if using S3)
-- ============================================================================

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

-- ============================================================================
-- Redis Keys
-- ============================================================================

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

-- ============================================================================
-- Web Push (VAPID) - Add if you have VAPID keys
-- ============================================================================

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

-- ============================================================================
-- Application Config
-- ============================================================================

SELECT store_api_key('PORT', 'app', 
    '3000', 
    'Application Port', 
    'production'
);

SELECT store_api_key('NODE_ENV', 'app', 
    'development',
    'Node Environment', 
    'production'
);

-- ============================================================================
-- Verification: List all stored keys (metadata only)
-- ============================================================================

SELECT * FROM api_keys_metadata ORDER BY key_category, key_name;

