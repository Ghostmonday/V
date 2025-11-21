-- ===============================================
-- 1. CONFIGURATION & EXTENSIONS
-- ===============================================
SET search_path TO service, public;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;

-- Create service schema for privileged operations
CREATE SCHEMA IF NOT EXISTS service;
