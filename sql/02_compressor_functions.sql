-- ===============================================
-- FILE: 02_compressor_functions.sql
-- PURPOSE: Compression pipeline functions and encode queue management
-- DEPENDENCIES: 01_vibez_schema.sql
-- ===============================================

SET search_path TO service, public;

-- ===============================================
-- UTILITY FUNCTIONS
-- ===============================================

-- SHA256 hex helper: Immutable hash function
CREATE OR REPLACE FUNCTION sha256_hex(data bytea) RETURNS TEXT AS $$
  SELECT encode(digest($1, 'sha256'), 'hex');
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- ===============================================
-- INTAKE STAGE
-- ===============================================

-- Intake log: Insert raw payload and return UUID for enqueueing
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

-- ===============================================
-- ENCODE QUEUE MANAGEMENT
-- ===============================================

-- Enqueue encode: Add raw log to compression queue
CREATE OR REPLACE FUNCTION enqueue_encode(raw_id UUID) RETURNS UUID AS $$
DECLARE
  queue_id UUID;
BEGIN
  INSERT INTO service.encode_queue (raw_id, status)
  VALUES (raw_id, 'pending')
  RETURNING id INTO queue_id;
  RETURN queue_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Claim encode batch: Atomically claim pending items with enriched data
-- Returns JSONB array with id, raw_id, mime_type for efficient sorting
CREATE OR REPLACE FUNCTION claim_encode_batch(p_limit INT)
RETURNS SETOF JSONB AS $$
BEGIN
  RETURN QUERY
  WITH cte AS (
    SELECT eq.id, eq.raw_id
    FROM service.encode_queue eq
    WHERE eq.status = 'pending'
      AND eq.attempts < eq.max_attempts
    ORDER BY eq.created_at ASC
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  ),
  upd AS (
    UPDATE service.encode_queue q
    SET status = 'processing',
        last_attempt_at = now(),
        attempts = attempts + 1
    FROM cte
    WHERE q.id = cte.id
    RETURNING q.id, q.raw_id, q.attempts, q.max_attempts
  )
  SELECT jsonb_build_object(
    'id', upd.id,
    'raw_id', upd.raw_id,
    'mime_type', lr.mime_type,
    'attempts', upd.attempts,
    'max_attempts', upd.max_attempts
  )
  FROM upd
  JOIN logs_raw lr ON lr.id = upd.raw_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Mark encode done: Update queue status after successful compression
CREATE OR REPLACE FUNCTION mark_encode_done(
  queue_id UUID,
  compressed_id UUID
) RETURNS VOID AS $$
BEGIN
  UPDATE service.encode_queue
  SET status = 'done',
      last_attempt_at = now()
  WHERE id = queue_id;
  
  -- Mark raw log as processed
  UPDATE logs_raw
  SET processed = TRUE
  WHERE id = (SELECT raw_id FROM service.encode_queue WHERE id = queue_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Mark encode failed: Record error and handle retry logic
CREATE OR REPLACE FUNCTION mark_encode_failed(
  queue_id UUID,
  error_msg TEXT
) RETURNS VOID AS $$
DECLARE
  v_attempts INT;
  v_max_attempts INT;
BEGIN
  SELECT attempts, max_attempts INTO v_attempts, v_max_attempts
  FROM service.encode_queue
  WHERE id = queue_id;
  
  IF v_attempts >= v_max_attempts THEN
    UPDATE service.encode_queue
    SET status = 'failed',
        error = error_msg,
        last_attempt_at = now()
    WHERE id = queue_id;
  ELSE
    UPDATE service.encode_queue
    SET status = 'pending', -- Retry
        error = error_msg,
        last_attempt_at = now()
    WHERE id = queue_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- ===============================================
-- ENCODE STAGE
-- ===============================================

-- Encode raw to compressed: Insert pre-compressed payload from Edge
-- Edge Function compresses payload, this function stores it
CREATE OR REPLACE FUNCTION encode_raw_to_compressed(
  raw_id UUID,
  codec TEXT DEFAULT 'lz4',
  compressed bytea
) RETURNS UUID AS $$
DECLARE
  raw_row RECORD;
  cmp_id UUID;
  csum TEXT;
BEGIN
  SELECT * INTO STRICT raw_row
  FROM logs_raw
  WHERE id = raw_id
  FOR UPDATE;
  
  IF raw_row.processed THEN
    RAISE EXCEPTION 'raw_id % already processed', raw_id;
  END IF;
  
  csum := sha256_hex(compressed);
  
  INSERT INTO logs_compressed (
    room_id,
    partition_month,
    codec,
    compressed_payload,
    original_length,
    checksum
  )
  VALUES (
    raw_row.room_id,
    to_char(raw_row.created_at, 'YYYY_MM'),
    codec,
    compressed,
    raw_row.length_bytes,
    csum
  )
  RETURNING id INTO cmp_id;
  
  RETURN cmp_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- ===============================================
-- ACCESS STAGE
-- ===============================================

-- Fetch compressed: Return compressed payload for Edge decompression
CREATE OR REPLACE FUNCTION fetch_compressed(compressed_id UUID)
RETURNS bytea AS $$
DECLARE
  row RECORD;
BEGIN
  SELECT compressed_payload INTO STRICT row
  FROM logs_compressed
  WHERE id = compressed_id;
  
  RETURN row.compressed_payload;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- ===============================================
-- DISPOSAL STAGE
-- ===============================================

-- Dispose compressed: Mark for deletion or secure purge
CREATE OR REPLACE FUNCTION dispose_compressed(
  compressed_id UUID,
  purge BOOLEAN DEFAULT FALSE
) RETURNS VOID AS $$
BEGIN
  IF purge THEN
    UPDATE logs_compressed
    SET compressed_payload = '\\x',
        lifecycle_state = 'deleted',
        cold_storage_uri = NULL
    WHERE id = compressed_id;
  ELSE
    UPDATE logs_compressed
    SET lifecycle_state = 'deleted'
    WHERE id = compressed_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- ===============================================
-- AUDIT CHAIN (Race-Safe)
-- ===============================================

-- Audit append: Race-safe append with per-node advisory lock
-- Uses pg_try_advisory_xact_lock to prevent concurrent chain appends
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
  -- Get or set node_id
  node_id_val := current_setting('app.node_id', true);
  IF node_id_val IS NULL OR node_id_val = '' THEN
    node_id_val := 'local';
    PERFORM set_config('app.node_id', node_id_val, false);
  END IF;
  
  -- Per-node advisory lock (hash of node_id)
  lock_key := hashtext(node_id_val);
  
  IF NOT pg_try_advisory_xact_lock(lock_key) THEN
    RAISE EXCEPTION 'Audit chain lock contention for node_id: %', node_id_val;
  END IF;
  
  -- Get previous chain hash for this node
  SELECT chain_hash INTO prev_chain
  FROM audit_log
  WHERE node_id = node_id_val
  ORDER BY id DESC
  LIMIT 1;
  
  IF prev_chain IS NULL THEN
    prev_chain := 'genesis';
  END IF;
  
  -- Canonicalize event
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
  
  -- Compute hash
  h := sha256_hex(canonical::bytea);
  
  -- Chain hash: sha256(prev_chain || current_hash)
  p_hash := sha256_hex((prev_chain || h)::bytea);
  
  -- Insert audit entry
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

