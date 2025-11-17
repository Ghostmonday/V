-- ===============================================
-- Phase 8: Encrypt Existing PII Data
-- Purpose: Migration script to encrypt existing plaintext PII
-- Note: This should be run via the Node.js migration service, not directly
-- ===============================================

-- This migration is handled by the Node.js service: src/services/pii-encryption-integration.ts
-- Run: migratePIIToEncrypted() function

-- The SQL below is for reference only - actual encryption happens in Node.js

-- Check for unencrypted emails (those without ':' separator used in encrypted format)
-- SELECT COUNT(*) FROM users WHERE email IS NOT NULL AND email NOT LIKE '%:%';

-- Check for unencrypted IP addresses in refresh_tokens
-- SELECT COUNT(*) FROM refresh_tokens WHERE ip_address IS NOT NULL AND ip_address NOT LIKE '%:%';

-- After migration, verify encryption:
-- SELECT id, 
--   CASE WHEN email LIKE '%:%' THEN 'encrypted' ELSE 'plaintext' END as email_status
-- FROM users 
-- WHERE email IS NOT NULL
-- LIMIT 10;

