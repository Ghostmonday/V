-- ============================================================================
-- QUICK START: Populate API Keys with Your Current Values
-- Copy-paste this into Supabase SQL Editor and run
-- ============================================================================

-- First, set your master encryption key (generate one first):
-- SELECT encode(gen_random_bytes(32), 'hex');
-- Then set it: ALTER DATABASE postgres SET app.encryption_key = 'your-hex-key-here';

-- ============================================================================
-- Apple Keys (UPDATE THESE WITH YOUR VALUES)
-- ============================================================================

SELECT store_api_key('APPLE_TEAM_ID', 'apple', 
    'R7KX4HNBFY',  -- ✅ Your actual 10-char Team ID
    'Apple Developer Team ID', 
    'production'
);

SELECT store_api_key('APPLE_KEY_ID', 'apple', 
    'YOUR_20_CHARACTER_KEY_ID',  -- ⚠️ REPLACE THIS
    'Apple Auth Key ID', 
    'production'
);

SELECT store_api_key('APPLE_PRIVATE_KEY', 'apple', 
    '-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgxQHhc41TtTTNCzgh
mmijh49p1NskcH8ZnADPL83RRRugCgYIKoZIzj0DAQehRANCAARXFQ+foo6dhWPb
yPNLK9+nUYBkPFlC+ED3hMm/aLQBsXG4p364imbImgMxGFrDVzKx/HJTSfx+HSjw
fqj4n5gB
-----END PRIVATE KEY-----',  -- ✅ Already set
    'Apple Private Key', 
    'production'
);

SELECT store_api_key('APPLE_SERVICE_ID', 'apple', 'com.ghostmonday.vibez', 'Apple Service ID', 'production');
SELECT store_api_key('APPLE_CLIENT_ID', 'apple', 'com.ghostmonday.vibez', 'Apple Client ID', 'production');

-- ============================================================================
-- Supabase Keys (✅ Already configured)
-- ============================================================================

SELECT store_api_key('NEXT_PUBLIC_SUPABASE_URL', 'supabase', 
    'https://iepjdfcbkmwhqshtyevg.supabase.co', 
    'Supabase Project URL', 
    'production'
);

SELECT store_api_key('SUPABASE_SERVICE_ROLE_KEY', 'supabase', 
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImllcGpkZmNia213aHFzaHR5ZXZnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjM0NTg5NSwiZXhwIjoyMDc3OTIxODk1fQ.6weILWfT8MMmDnCBJQ767Htq4gGT7KxU-ctGCtT5i2E', 
    'Supabase Service Role Key', 
    'production'
);

-- ============================================================================
-- LiveKit Keys (✅ Already configured)
-- ============================================================================

SELECT store_api_key('LIVEKIT_API_KEY', 'livekit', 'APIXwuVneVRyb42', 'LiveKit API Key', 'production');
SELECT store_api_key('LIVEKIT_API_SECRET', 'livekit', '01MTuGypDhRfy4CLxChG9IYUteS235F2OYfor04DjsQA', 'LiveKit API Secret', 'production');
SELECT store_api_key('LIVEKIT_URL', 'livekit', 'wss://vibez-ysfq2dir.livekit.cloud', 'LiveKit URL', 'production');
SELECT store_api_key('LIVEKIT_HOST', 'livekit', 'vibez-ysfq2dir.livekit.cloud', 'LiveKit Host', 'production');

-- ============================================================================
-- JWT Secret (✅ Already configured)
-- ============================================================================

SELECT store_api_key('JWT_SECRET', 'auth', 
    '22b535f33e962ec929111875334a9911d12ea843b73137cfa8ff0162a8ec10d3', 
    'JWT Signing Secret', 
    'production'
);

-- ============================================================================
-- Verify: Check what was stored (metadata only, no values)
-- ============================================================================

SELECT key_name, key_category, description, environment, is_active 
FROM api_keys_metadata 
ORDER BY key_category, key_name;

-- ============================================================================
-- Test: Retrieve a key (should return decrypted value)
-- ============================================================================

-- SELECT get_api_key('JWT_SECRET', 'production');
-- SELECT get_api_key('APPLE_TEAM_ID', 'production');

