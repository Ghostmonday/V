-- ===============================================
-- FILE: 03_retention_policy.sql
-- PURPOSE: Retention scheduling, cold storage, and legal holds
-- DEPENDENCIES: 01_vibez_schema.sql, 02_compressor_functions.sql
-- ===============================================

SET search_path TO service, public;

-- ===============================================
-- RETENTION SCHEDULING
-- ===============================================

-- Schedule retention: Enqueue hot→cold and cold→delete transitions
-- Respects room-level retention overrides and legal holds
CREATE OR REPLACE FUNCTION schedule_retention() RETURNS JSONB AS $$
DECLARE
  conf JSONB;
  hot_days INT;
  cold_days INT;
  hot_count INT := 0;
  cold_count INT := 0;
  r RECORD;
BEGIN
  -- Get system defaults
  SELECT value INTO conf
  FROM system_config
  WHERE key = 'retention_policy';
  
  hot_days := COALESCE((conf->>'hot_retention_days')::INT, 30);
  cold_days := COALESCE((conf->>'cold_retention_days')::INT, 365);
  
  -- Schedule hot→cold transitions
  -- Join with rooms to get room-level overrides
  FOR r IN
    SELECT lc.id, lc.room_id, lc.created_at,
           COALESCE(r.retention_hot_days, hot_days) AS effective_hot_days
    FROM logs_compressed lc
    LEFT JOIN rooms r ON r.id = lc.room_id
    WHERE lc.lifecycle_state = 'hot'
      AND lc.created_at < now() - make_interval(days => COALESCE(r.retention_hot_days, hot_days))
      AND lc.id NOT IN (
        SELECT resource_id
        FROM retention_schedule
        WHERE resource_type = 'logs_compressed'
          AND resource_id = lc.id
      )
      AND lc.id NOT IN (
        SELECT resource_id
        FROM legal_holds
        WHERE resource_type = 'logs_compressed'
          AND resource_id = lc.id
          AND hold_until > now()
      )
  LOOP
    INSERT INTO retention_schedule (
      resource_type,
      resource_id,
      scheduled_for,
      action
    )
    VALUES (
      'logs_compressed',
      r.id,
      now(),
      'move_to_cold'
    )
    ON CONFLICT DO NOTHING;
    
    hot_count := hot_count + 1;
  END LOOP;
  
  -- Schedule cold→delete transitions
  FOR r IN
    SELECT lc.id, lc.room_id, lc.created_at,
           COALESCE(r.retention_cold_days, cold_days) AS effective_cold_days
    FROM logs_compressed lc
    LEFT JOIN rooms r ON r.id = lc.room_id
    WHERE lc.lifecycle_state = 'cold'
      AND lc.created_at < now() - make_interval(days => COALESCE(r.retention_cold_days, cold_days))
      AND lc.id NOT IN (
        SELECT resource_id
        FROM retention_schedule
        WHERE resource_type = 'logs_compressed'
          AND resource_id = lc.id
      )
      AND lc.id NOT IN (
        SELECT resource_id
        FROM legal_holds
        WHERE resource_type = 'logs_compressed'
          AND resource_id = lc.id
          AND hold_until > now()
      )
  LOOP
    INSERT INTO retention_schedule (
      resource_type,
      resource_id,
      scheduled_for,
      action
    )
    VALUES (
      'logs_compressed',
      r.id,
      now(),
      'delete'
    )
    ON CONFLICT DO NOTHING;
    
    cold_count := cold_count + 1;
  END LOOP;
  
  RETURN jsonb_build_object(
    'hot_scheduled', hot_count,
    'cold_scheduled', cold_count,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- ===============================================
-- COLD STORAGE MANAGEMENT
-- ===============================================

-- Mark cold storage: Update lifecycle state and S3 URI after upload
CREATE OR REPLACE FUNCTION mark_cold_storage(
  compressed_id UUID,
  uri TEXT
) RETURNS VOID AS $$
BEGIN
  UPDATE logs_compressed
  SET cold_storage_uri = uri,
      lifecycle_state = 'cold'
  WHERE id = compressed_id
    AND lifecycle_state = 'hot'; -- Idempotent: only if still hot
  
  -- Update retention schedule status
  UPDATE retention_schedule
  SET status = 'done'
  WHERE resource_type = 'logs_compressed'
    AND resource_id = compressed_id
    AND action = 'move_to_cold';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- ===============================================
-- LEGAL HOLDS
-- ===============================================

-- Apply legal hold: Prevent disposal of resources under legal hold
CREATE OR REPLACE FUNCTION apply_legal_hold(
  resource_type TEXT,
  resource_id UUID,
  hold_until TIMESTAMPTZ,
  reason TEXT,
  actor TEXT
) RETURNS VOID AS $$
BEGIN
  -- Insert legal hold
  INSERT INTO legal_holds (
    resource_type,
    resource_id,
    hold_until,
    reason,
    actor
  )
  VALUES (
    resource_type,
    resource_id,
    hold_until,
    reason,
    actor
  )
  ON CONFLICT DO NOTHING;
  
  -- Mark retention schedule as on hold
  UPDATE retention_schedule
  SET on_hold = TRUE,
      hold_reason = reason,
      status = 'on_hold'
  WHERE resource_type = apply_legal_hold.resource_type
    AND resource_id = apply_legal_hold.resource_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Release legal hold: Allow normal retention processing
CREATE OR REPLACE FUNCTION release_legal_hold(
  resource_type TEXT,
  resource_id UUID
) RETURNS VOID AS $$
BEGIN
  -- Delete legal hold
  DELETE FROM legal_holds
  WHERE resource_type = release_legal_hold.resource_type
    AND resource_id = release_legal_hold.resource_id;
  
  -- Release retention schedule hold
  UPDATE retention_schedule
  SET on_hold = FALSE,
      hold_reason = NULL,
      status = 'pending'
  WHERE resource_type = release_legal_hold.resource_type
    AND resource_id = release_legal_hold.resource_id
    AND on_hold = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

