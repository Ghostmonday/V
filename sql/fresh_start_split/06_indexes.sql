-- ===============================================
-- 6. INDEXES
-- ===============================================

-- Core indexes
CREATE INDEX IF NOT EXISTS idx_messages_room_time ON messages (room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_hash ON messages (content_hash);
CREATE INDEX IF NOT EXISTS idx_messages_flagged ON messages (is_flagged) WHERE is_flagged = true;
CREATE INDEX IF NOT EXISTS idx_messages_partition ON messages (partition_month);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_reactions ON messages USING GIN (reactions);
CREATE INDEX IF NOT EXISTS idx_messages_thread_id ON messages (thread_id) WHERE thread_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_reply_to ON messages (reply_to) WHERE reply_to IS NOT NULL;

-- Audit and logs
CREATE INDEX IF NOT EXISTS idx_audit_room_time ON audit_log (room_id, event_time DESC);
CREATE INDEX IF NOT EXISTS idx_audit_node_chain ON audit_log (node_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_audit_event_type ON audit_log (event_type);
CREATE INDEX IF NOT EXISTS idx_logs_raw_room_month ON logs_raw (room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_logs_compressed_room_month ON logs_compressed (room_id, partition_month, created_at DESC);

-- Feature indexes
CREATE INDEX IF NOT EXISTS idx_threads_parent_message ON threads (parent_message_id);
CREATE INDEX IF NOT EXISTS idx_threads_room_id ON threads (room_id) WHERE is_archived = FALSE;
CREATE INDEX IF NOT EXISTS idx_threads_updated_at ON threads (updated_at DESC) WHERE is_archived = FALSE;
CREATE INDEX IF NOT EXISTS idx_edit_history_message_id ON edit_history (message_id);
CREATE INDEX IF NOT EXISTS idx_edit_history_edited_at ON edit_history (edited_at DESC);
CREATE INDEX IF NOT EXISTS idx_embeddings_vector ON embeddings USING hnsw (vector vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- User and room indexes
CREATE INDEX IF NOT EXISTS idx_users_handle ON users (handle);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_room_memberships_room_user ON room_memberships (room_id, user_id);
CREATE INDEX IF NOT EXISTS idx_room_memberships_user_role ON room_memberships (user_id, role);

-- API keys and privacy
CREATE INDEX IF NOT EXISTS idx_api_keys_name ON api_keys(key_name);
CREATE INDEX IF NOT EXISTS idx_api_keys_category ON api_keys(key_category);
CREATE INDEX IF NOT EXISTS idx_zkp_commitments_user_id ON user_zkp_commitments(user_id, created_at DESC);

-- Refresh Tokens
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_family_id ON refresh_tokens(family_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- Auth Audit
CREATE INDEX IF NOT EXISTS idx_auth_audit_user_id ON auth_audit_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_auth_audit_event_type ON auth_audit_log(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_auth_audit_created_at ON auth_audit_log(created_at DESC);
