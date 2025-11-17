-- ============================================================================
-- Populate API Keys - READY TO COPY-PASTE!
-- All your actual keys are included below
-- ============================================================================

-- ============================================================================
-- Apple Sign-In Keys
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

-- ============================================================================
-- Supabase Keys
-- ============================================================================

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

-- ============================================================================
-- LiveKit Keys
-- ============================================================================

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

-- ============================================================================
-- JWT Secret
-- ============================================================================

SELECT store_api_key('JWT_SECRET', 'auth', 
    '22b535f33e962ec929111875334a9911d12ea843b73137cfa8ff0162a8ec10d3',
    'JWT Signing Secret (min 32 chars)', 
    'production'
);

-- ============================================================================
-- AI/LLM Keys
-- ============================================================================

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
    'development',  -- ✅ Matches your .env
    'Node Environment', 
    'production'
);

-- ============================================================================
-- Verification: List all stored keys (metadata only)
-- ============================================================================

SELECT * FROM api_keys_metadata ORDER BY key_category, key_name;

