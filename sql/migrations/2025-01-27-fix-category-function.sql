-- ============================================================================
-- Fix get_api_keys_by_category function - resolve ambiguous column reference
-- ============================================================================

-- Drop the old function first (since return type changed)
DROP FUNCTION IF EXISTS get_api_keys_by_category(VARCHAR, VARCHAR);

-- Recreate with new return type
CREATE FUNCTION get_api_keys_by_category(
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
        
        -- Return the row (using different names to avoid conflicts)
        result_key_name := v_key_name;
        result_key_value := v_key_value;
        result_description := v_description;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

