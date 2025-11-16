-- ===============================================
-- FILE: 06_partition_management.sql
-- PURPOSE: Dynamic partition creation for logs_compressed
-- DEPENDENCIES: 01_vibez_schema.sql
-- ===============================================

SET search_path TO service, public;

-- ===============================================
-- PARTITION CREATION
-- ===============================================

-- Create partition if needed: Idempotent partition creation
-- Called by compression worker before inserting to ensure partition exists
CREATE OR REPLACE FUNCTION create_partition_if_needed(partition_month TEXT)
RETURNS TEXT AS $$
DECLARE
  partition_name TEXT;
  start_date DATE;
  end_date DATE;
  start_bound TEXT;
  end_bound TEXT;
BEGIN
  -- Validate partition_month format (YYYY_MM)
  IF partition_month !~ '^\d{4}_\d{2}$' THEN
    RAISE EXCEPTION 'Invalid partition_month format: %. Expected YYYY_MM', partition_month;
  END IF;
  
  -- Convert to date bounds
  start_date := to_date(replace(partition_month, '_', '-') || '-01', 'YYYY-MM-DD');
  end_date := (start_date + INTERVAL '1 month')::DATE;
  
  start_bound := partition_month || '_01';
  end_bound := to_char(end_date, 'YYYY_MM') || '_01';
  
  partition_name := 'logs_compressed_' || replace(partition_month, '_', '');
  
  -- Create partition if it doesn't exist
  EXECUTE format(
    'CREATE TABLE IF NOT EXISTS %I PARTITION OF logs_compressed
     FOR VALUES FROM (%L) TO (%L)',
    partition_name,
    start_bound,
    end_bound
  );
  
  -- Create index on partition if it doesn't exist
  EXECUTE format(
    'CREATE INDEX IF NOT EXISTS idx_%I_room_month
     ON %I (room_id, partition_month, created_at DESC)',
    partition_name,
    partition_name
  );
  
  RETURN partition_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- ===============================================
-- PARTITION UTILITIES
-- ===============================================

-- List all partitions: Returns partition names and row counts
CREATE OR REPLACE FUNCTION list_partitions()
RETURNS TABLE (
  partition_name TEXT,
  partition_month TEXT,
  row_count BIGINT,
  total_size TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    schemaname || '.' || tablename AS partition_name,
    tablename AS partition_month,
    n_live_tup AS row_count,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size
  FROM pg_stat_user_tables
  WHERE tablename LIKE 'logs_compressed_%'
    AND tablename != 'logs_compressed_default'
  ORDER BY tablename DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Drop old partition: Safely drop partition after data migration
-- TODO: Add validation to ensure partition is empty or migrated
CREATE OR REPLACE FUNCTION drop_partition(partition_month TEXT)
RETURNS VOID AS $$
DECLARE
  partition_name TEXT;
BEGIN
  partition_name := 'logs_compressed_' || replace(partition_month, '_', '');
  
  -- Safety check: Only drop if partition exists and is not default
  IF partition_name = 'logs_compressed_default' THEN
    RAISE EXCEPTION 'Cannot drop default partition';
  END IF;
  
  EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- ===============================================
-- TABLE SIZE UTILITY
-- ===============================================

-- Get table size: Returns total size of a table including indexes
CREATE OR REPLACE FUNCTION get_table_size(table_name text)
RETURNS bigint AS $$
  SELECT pg_total_relation_size(table_name);
$$ LANGUAGE sql SECURITY DEFINER;

