# VibeZ Supabase SQL Consolidated Master Sheet

This document provides a comprehensive overview and consolidation of all SQL files in the VibeZ project, organized by functionality and execution order.

## Table of Contents

1. [Overview](#overview)
2. [Execution Order](#execution-order)
3. [Core Schema](#core-schema)
4. [Functions & Procedures](#functions--procedures)
5. [Security & RLS](#security--rls)
6. [Feature Tables](#feature-tables)
7. [Migrations](#migrations)
8. [Performance & Indexing](#performance--indexing)
9. [Validation & Testing](#validation--testing)
10. [Maintenance Scripts](#maintenance-scripts)

---

## Overview

The VibeZ SQL architecture consists of:
- **Core Tables**: 20+ tables for messaging, users, rooms, and audit
- **Security**: Comprehensive RLS policies and audit logging
- **Features**: AI integration, bots, assistants, and analytics
- **Performance**: Partition management and optimized indexes
- **Privacy**: ZKP commitments and encrypted API key vault

## Execution Order

Execute SQL files in this order for a fresh installation:

### Phase 1: Core Setup
```sql
-- 1. Enable Extensions
01_sinapse_schema.sql      -- Core schema, tables, and extensions
02_compressor_functions.sql -- Compression pipeline functions
03_retention_policy.sql     -- Retention and lifecycle management
06_partition_management.sql -- Dynamic partition creation
```

### Phase 2: Security
```sql
-- 2. Security Layer
05_rls_policies.sql         -- Row-level security policies
08_enhanced_rls_policies.sql -- Enhanced RLS (if needed)
```

### Phase 3: Features
```sql
-- 3. Feature Tables
09_p0_features.sql          -- Reactions, threads, edit history
10_integrated_features.sql  -- AI assistants, bots, embeddings
11_indexing_and_rls.sql     -- Performance indexes and AI views
```

### Phase 4: Migrations
```sql
-- 4. Apply Migrations (in date order)
migrations/2025-11-15-vibes-core-schema.sql
migrations/2025-01-27-api-keys-vault.sql
migrations/2025-01-add-moderation-tables.sql
migrations/2025-01-XX-privacy-zkp-commitments.sql
-- ... other migrations in chronological order
```

### Phase 5: Validation
```sql
-- 5. Verify Setup
12_verify_setup.sql
validate-phases-1-3.sql
```

---

## Core Schema

### Primary Tables

#### Users Table
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  handle TEXT NOT NULL UNIQUE,
  display_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_verified BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}'::jsonb,
  policy_flags JSONB DEFAULT '{}'::jsonb,
  last_seen TIMESTAMPTZ,
  federation_id TEXT UNIQUE
);
```

#### Rooms Table
```sql
CREATE TABLE rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_public BOOLEAN NOT NULL DEFAULT true,
  partition_month TEXT GENERATED ALWAYS AS (to_char(date_trunc('month', created_at AT TIME ZONE 'UTC'), 'YYYY_MM')) STORED,
  metadata JSONB DEFAULT '{}'::jsonb,
  fed_node_id TEXT,
  retention_hot_days INT,
  retention_cold_days INT
);
```

#### Messages Table
```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload_ref TEXT NOT NULL,
  content_preview TEXT,
  content_hash TEXT NOT NULL,
  audit_hash_chain TEXT NOT NULL,
  flags JSONB DEFAULT '{}'::jsonb,
  is_flagged BOOLEAN NOT NULL DEFAULT FALSE,
  is_exported BOOLEAN NOT NULL DEFAULT FALSE,
  partition_month TEXT NOT NULL GENERATED ALWAYS AS (to_char(date_trunc('month', created_at AT TIME ZONE 'UTC'), 'YYYY_MM')) STORED,
  fed_origin_hash TEXT,
  -- P0 features
  reactions JSONB DEFAULT '[]'::jsonb,
  thread_id UUID REFERENCES threads(id) ON DELETE SET NULL,
  reply_to UUID REFERENCES messages(id) ON DELETE SET NULL,
  is_edited BOOLEAN DEFAULT FALSE
);
```

### Support Tables

- **room_memberships**: User roles and permissions in rooms
- **message_receipts**: Delivery and read receipts
- **audit_log**: Immutable audit trail
- **logs_raw**: Raw message intake
- **logs_compressed**: Compressed message storage
- **system_config**: System configuration

---

## Functions & Procedures

### Compression Pipeline
```sql
-- From 02_compressor_functions.sql
intake_log(room UUID, payload BYTEA, mime TEXT)
encode_raw_to_compressed(raw_id UUID, codec TEXT, compressed BYTEA)
fetch_compressed(compressed_id UUID)
audit_append(evt_type TEXT, room UUID, usr UUID, msg UUID, pload JSONB, actor TEXT, sig TEXT)
```

### Retention Management
```sql
-- From 03_retention_policy.sql
schedule_retention()
mark_cold_storage(compressed_id UUID, uri TEXT)
apply_legal_hold(resource_type TEXT, resource_id UUID, hold_until TIMESTAMPTZ, reason TEXT, actor TEXT)
release_legal_hold(resource_type TEXT, resource_id UUID)
```

### Partition Management
```sql
-- From 06_partition_management.sql
create_partition_if_needed(partition_month TEXT)
list_partitions()
drop_partition(partition_month TEXT)
get_table_size(table_name TEXT)
```

---

## Security & RLS

### RLS Policies Overview
```sql
-- From 05_rls_policies.sql
-- Audit Log: Append-only, service role only
-- Messages: Users can insert/read in their rooms
-- Logs: Service role only
-- System Config: Service role only
```

### Key Security Features
- Row-level security on all tables
- Immutable audit log with hash chain
- Service role isolation for sensitive operations
- JWT-based user authentication helpers

---

## Feature Tables

### P0 Features
- **threads**: Message threading
- **edit_history**: Message edit tracking
- **message_search_index**: Full-text search
- **bot_endpoints**: Bot webhook management

### AI Integration
- **assistants**: LLM assistant configurations
- **bots**: Bot registrations and tokens
- **embeddings**: Vector embeddings for semantic search
- **subscriptions**: Push notification subscriptions

### Analytics & Monitoring
- **metrics**: Performance metrics
- **presence_logs**: User presence tracking
- **telemetry**: System telemetry

---

## Migrations

### Key Migrations

#### API Keys Vault (2025-01-27)
```sql
-- Secure storage for all API keys
CREATE TABLE api_keys (
    id UUID PRIMARY KEY,
    key_name VARCHAR(100) NOT NULL UNIQUE,
    key_category VARCHAR(50) NOT NULL,
    encrypted_value BYTEA NOT NULL,
    -- ... security fields
);

-- Helper functions
store_api_key(name, category, value, description)
get_api_key(name, environment)
```

#### Privacy Features (ZKP)
```sql
-- Zero-knowledge proof commitments
CREATE TABLE user_zkp_commitments (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    attribute_type TEXT NOT NULL,
    commitment TEXT NOT NULL,
    -- ... proof data
);
```

#### Moderation Tables
```sql
-- Message violations and user mutes
CREATE TABLE message_violations (...)
CREATE TABLE user_mutes (...)
```

---

## Performance & Indexing

### Critical Indexes
```sql
-- Messages
CREATE INDEX idx_messages_room_time ON messages (room_id, created_at DESC);
CREATE INDEX idx_messages_flagged ON messages (is_flagged) WHERE is_flagged = true;

-- Audit
CREATE INDEX idx_audit_room_time ON audit_log (room_id, event_time DESC);
CREATE INDEX idx_audit_node_chain ON audit_log (node_id, id DESC);

-- Search
CREATE INDEX idx_message_search_vector ON message_search_index USING GIN (search_vector);

-- Embeddings (Vector)
CREATE INDEX idx_embeddings_vector ON embeddings USING hnsw (vector vector_cosine_ops);
```

### AI-Optimized Views
```sql
-- From 11_indexing_and_rls.sql
ai_bot_monitoring          -- Bot health monitoring
ai_message_quality         -- Message quality control
ai_presence_trends         -- User behavior patterns
ai_audit_summary          -- Audit trail analysis
ai_query_performance      -- Performance monitoring
ai_moderation_suggestions -- Moderation recommendations
ai_telemetry_insights     -- System telemetry
```

---

## Validation & Testing

### Validation Scripts
```sql
-- Check RLS status
VERIFY_RLS_STATUS.sql
DIAGNOSE_RLS_STATUS.sql

-- Performance validation
16_performance_tests.sql

-- Phase validation
validate-phases-1-3.sql
```

### Quick Validation
```sql
-- From QUICK_VALIDATION.sql
-- Verify all tables exist
-- Check RLS is enabled
-- Validate indexes
-- Test basic operations
```

---

## Maintenance Scripts

### RLS Management
```sql
ENABLE_RLS_ON_ALL_TABLES.sql
COMPLETE_RLS_AUDIT_AND_FIX.sql
FIX_CRITICAL_RLS_GAPS.sql
```

### Cleanup Scripts
```sql
CLEANUP_DUPLICATE_POLICIES.sql
CLEANUP_ALL_DUPLICATE_POLICIES.sql
AGGRESSIVE_CLEANUP_DUPLICATES.sql
```

### Security Audits
```sql
COMPLETE_SECURITY_AUDIT.md
COMPLETE_SECURITY_FIX.sql
```

---

## System Configuration

### Default Configuration
```sql
-- From system_config table
retention_policy: {hot_retention_days: 30, cold_retention_days: 365}
moderation_thresholds: {default: 0.6, illegal: 0.7, threat: 0.6, ...}
codec: {preferences: {text/plain: lz4, ...}}
```

### LLM Parameters
```sql
-- @llm_param annotations throughout for AI tuning:
-- Moderation thresholds
-- Temperature settings
-- Embedding models
-- Search similarity thresholds
```

---

## Best Practices

1. **Always run in transaction blocks** for multi-statement operations
2. **Check for existence** before creating (IF NOT EXISTS)
3. **Use SECURITY DEFINER** for privileged functions
4. **Enable RLS** on all user-facing tables
5. **Create indexes** for foreign keys and common queries
6. **Document with comments** for complex logic
7. **Version migrations** with timestamps

---

## Quick Start Commands

### Fresh Installation
```bash
# Run all core files in order
psql -d your_database -f sql/01_sinapse_schema.sql
psql -d your_database -f sql/02_compressor_functions.sql
psql -d your_database -f sql/03_retention_policy.sql
psql -d your_database -f sql/05_rls_policies.sql
psql -d your_database -f sql/06_partition_management.sql
psql -d your_database -f sql/09_p0_features.sql
psql -d your_database -f sql/10_integrated_features.sql
psql -d your_database -f sql/11_indexing_and_rls.sql

# Apply migrations
for f in sql/migrations/*.sql; do psql -d your_database -f "$f"; done
```

### Verification
```bash
# Run validation
psql -d your_database -f sql/12_verify_setup.sql
psql -d your_database -f sql/QUICK_VALIDATION.sql
```

---

## Troubleshooting

### Common Issues

1. **RLS not working**: Run `ENABLE_RLS_ON_ALL_TABLES.sql`
2. **Missing indexes**: Run `13_add_missing_indexes.sql`
3. **Duplicate policies**: Run `CLEANUP_DUPLICATE_POLICIES.sql`
4. **Performance issues**: Check `ai_query_performance` view

### Debug Queries
```sql
-- Check RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';

-- View active policies
SELECT tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public';

-- Check table sizes
SELECT * FROM list_partitions();
```

---

## Notes

- File naming convention: XX_purpose.sql (XX = execution order)
- Migration naming: YYYY-MM-DD-description.sql
- All timestamps in UTC
- UUID primary keys throughout
- JSONB for flexible metadata
- Partition by month for time-series data
