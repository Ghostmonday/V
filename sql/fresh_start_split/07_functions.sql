-- ===============================================
-- 7. FUNCTIONS
-- ===============================================

SET search_path = service, public;
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- SHA256 hex helper
CREATE OR REPLACE FUNCTION sha256_hex(data bytea) RETURNS TEXT AS $$
  SELECT encode(digest($1, 'sha256'), 'hex');
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- Intake log function
CREATE OR REPLACE FUNCTION intake_log(
  room UUID,
  payload BYTEA,
  mime TEXT
) RETURNS UUID AS $$
DECLARE
  rid UUID;
  csum TEXT;
BEGIN
  csum := sha256_hex(payload);
  INSERT INTO logs_raw (room_id, payload, mime_type, length_bytes, checksum)
  VALUES (room, payload, mime, octet_length(payload), csum)
  RETURNING id INTO rid;
  RETURN rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Audit append function
CREATE OR REPLACE FUNCTION audit_append(
  evt_type TEXT,
  room UUID,
  usr UUID,
  msg UUID,
  pload JSONB,
  actor TEXT DEFAULT 'system',
  sig TEXT DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
  p_hash TEXT;
  h TEXT;
  prev_chain TEXT;
  canonical TEXT;
  new_id BIGINT;
  lock_key BIGINT;
  node_id_val TEXT;
BEGIN
  node_id_val := current_setting('app.node_id', true);
  IF node_id_val IS NULL OR node_id_val = '' THEN
    node_id_val := 'local';
    PERFORM set_config('app.node_id', node_id_val, false);
  END IF;
  
  lock_key := hashtext(node_id_val);
  
  IF NOT pg_try_advisory_xact_lock(lock_key) THEN
    RAISE EXCEPTION 'Audit chain lock contention for node_id: %', node_id_val;
  END IF;
  
  SELECT chain_hash INTO prev_chain
  FROM audit_log
  WHERE node_id = node_id_val
  ORDER BY id DESC
  LIMIT 1;
  
  IF prev_chain IS NULL THEN
    prev_chain := 'genesis';
  END IF;
  
  canonical := jsonb_build_object(
    'event_time', now(),
    'event_type', evt_type,
    'room_id', room,
    'user_id', usr,
    'message_id', msg,
    'payload', pload,
    'actor', actor,
    'signature', sig,
    'node_id', node_id_val
  )::text;
  
  h := sha256_hex(canonical::bytea);
  p_hash := sha256_hex((prev_chain || h)::bytea);
  
  INSERT INTO audit_log (
    event_type,
    room_id,
    user_id,
    message_id,
    payload,
    actor,
    signature,
    hash,
    prev_hash,
    chain_hash,
    node_id
  )
  VALUES (
    evt_type,
    room,
    usr,
    msg,
    pload,
    actor,
    sig,
    h,
    prev_chain,
    p_hash,
    node_id_val
  )
  RETURNING id INTO new_id;
  
  RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- ===============================================
-- RETENTION & LIFECYCLE FUNCTIONS
-- ===============================================

-- Schedule retention: Enqueue hot→cold and cold→delete transitions
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
  FOR r IN
    SELECT lc.id, lc.room_id, lc.created_at,
           COALESCE(r.retention_hot_days, hot_days) AS effective_hot_days
    FROM logs_compressed lc
    LEFT JOIN rooms r ON r.id = lc.room_id
    WHERE lc.lifecycle_state = 'hot'
      AND lc.created_at < now() - make_interval(days => COALESCE(r.retention_hot_days, hot_days))
      AND lc.id NOT IN (
        SELECT resource_id FROM retention_schedule WHERE resource_type = 'logs_compressed' AND resource_id = lc.id
      )
      AND lc.id NOT IN (
        SELECT resource_id FROM legal_holds WHERE resource_type = 'logs_compressed' AND resource_id = lc.id AND hold_until > now()
      )
  LOOP
    INSERT INTO retention_schedule (resource_type, resource_id, scheduled_for, action)
    VALUES ('logs_compressed', r.id, now(), 'move_to_cold')
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
        SELECT resource_id FROM retention_schedule WHERE resource_type = 'logs_compressed' AND resource_id = lc.id
      )
      AND lc.id NOT IN (
        SELECT resource_id FROM retention_schedule WHERE resource_type = 'logs_compressed' AND resource_id = lc.id
      )
      AND lc.id NOT IN (
        SELECT resource_id FROM legal_holds WHERE resource_type = 'logs_compressed' AND resource_id = lc.id AND hold_until > now()
      )
  LOOP
    INSERT INTO retention_schedule (resource_type, resource_id, scheduled_for, action)
    VALUES ('logs_compressed', r.id, now(), 'delete')
    ON CONFLICT DO NOTHING;
    cold_count := cold_count + 1;
  END LOOP;
  
  RETURN jsonb_build_object('hot_scheduled', hot_count, 'cold_scheduled', cold_count, 'timestamp', now());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Mark cold storage
CREATE OR REPLACE FUNCTION mark_cold_storage(compressed_id UUID, uri TEXT) RETURNS VOID AS $$
BEGIN
  UPDATE logs_compressed
  SET cold_storage_uri = uri, lifecycle_state = 'cold'
  WHERE id = compressed_id AND lifecycle_state = 'hot';
  
  UPDATE retention_schedule
  SET status = 'done'
  WHERE resource_type = 'logs_compressed' AND resource_id = compressed_id AND action = 'move_to_cold';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Apply legal hold
CREATE OR REPLACE FUNCTION apply_legal_hold(resource_type TEXT, resource_id UUID, hold_until TIMESTAMPTZ, reason TEXT, actor TEXT) RETURNS VOID AS $$
BEGIN
  INSERT INTO legal_holds (resource_type, resource_id, hold_until, reason, actor)
  VALUES (resource_type, resource_id, hold_until, reason, actor)
  ON CONFLICT DO NOTHING;
  
  UPDATE retention_schedule
  SET on_hold = TRUE, hold_reason = reason, status = 'on_hold'
  WHERE resource_type = apply_legal_hold.resource_type AND resource_id = apply_legal_hold.resource_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Release legal hold
CREATE OR REPLACE FUNCTION release_legal_hold(resource_type TEXT, resource_id UUID) RETURNS VOID AS $$
BEGIN
  DELETE FROM legal_holds
  WHERE resource_type = release_legal_hold.resource_type AND resource_id = release_legal_hold.resource_id;
  
  UPDATE retention_schedule
  SET on_hold = FALSE, hold_reason = NULL, status = 'pending'
  WHERE resource_type = release_legal_hold.resource_type AND resource_id = release_legal_hold.resource_id AND on_hold = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Update timestamp function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- API Keys encryption helper
CREATE OR REPLACE FUNCTION get_encryption_key()
RETURNS BYTEA AS $$
BEGIN
    RETURN decode(current_setting('app.encryption_key', true), 'hex');
EXCEPTION
    WHEN OTHERS THEN
        RETURN digest('vibez-api-keys-master-key-change-this-in-production', 'sha256');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cleanup expired refresh tokens
CREATE OR REPLACE FUNCTION cleanup_expired_refresh_tokens()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM refresh_tokens
  WHERE expires_at < NOW() OR revoked_at IS NOT NULL;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Search functions
CREATE MATERIALIZED VIEW IF NOT EXISTS message_search_index AS
SELECT
  m.id,
  m.content_preview AS content,
  m.room_id,
  m.sender_id AS user_id,
  m.created_at,
  to_tsvector('english', COALESCE(m.content_preview, '')) AS search_vector
FROM messages m
WHERE m.thread_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_message_search_vector ON message_search_index USING GIN (search_vector);

-- Vector search function
CREATE OR REPLACE FUNCTION match_messages(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.78,
  match_count int DEFAULT 10,
  filter_room_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  room_id UUID,
  sender_id UUID,
  content_preview TEXT,
  created_at TIMESTAMPTZ,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id,
    m.room_id,
    m.sender_id,
    m.content_preview,
    m.created_at,
    1 - (e.vector <=> query_embedding) AS similarity
  FROM messages m
  INNER JOIN embeddings e ON e.message_id = m.id
  WHERE 
    (filter_room_id IS NULL OR m.room_id = filter_room_id)
    AND (1 - (e.vector <=> query_embedding)) > match_threshold
  ORDER BY e.vector <=> query_embedding
  LIMIT match_count;
END;
$$;

-- Partition month trigger function
CREATE OR REPLACE FUNCTION set_partition_month()
RETURNS TRIGGER AS $$
BEGIN
  NEW.partition_month := to_char(NEW.created_at, 'YYYY_MM');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
