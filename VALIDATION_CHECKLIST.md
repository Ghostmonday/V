# Phase 1-3 Validation Checklist

Use this checklist to manually validate all three phases. Run the automated validation scripts first, then use this for manual testing.

## Quick Start

```bash
# 1. Run TypeScript validation script
tsx scripts/validate-phases-1-3.ts

# 2. Run SQL validation script
psql $DATABASE_URL -f sql/validate-phases-1-3.sql

# 3. Review results
cat validation-results-phases-1-3.json
```

---

## Phase 1: Security & Authentication Hardening

### 1.1 Refresh Token Rotation & Security ✅

**Automated Checks:**
- [ ] Run `validate-phases-1-3.ts` - Phase 1.1 section
- [ ] Run SQL validation - refresh_tokens table check

**Manual Tests:**
- [ ] **Token Reuse Detection:**
  ```bash
  # 1. Login and get refresh token
  curl -X POST http://localhost:3000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"password"}'
  
  # 2. Use refresh token to get new access token
  curl -X POST http://localhost:3000/api/auth/refresh \
    -H "Content-Type: application/json" \
    -d '{"refreshToken":"<token>"}'
  
  # 3. Try to reuse the OLD refresh token (should fail)
  # 4. Check database - entire token family should be invalidated
  ```

- [ ] **Token Hashing:**
  ```sql
  -- Verify tokens are hashed (64 char hex)
  SELECT token_hash, LENGTH(token_hash) as hash_length
  FROM refresh_tokens
  LIMIT 5;
  -- All should be 64 characters and hex format
  ```

- [ ] **Audit Logging:**
  ```sql
  -- Check audit logs for token events
  SELECT event_type, user_id, created_at
  FROM audit_logs
  WHERE event_type LIKE '%token%'
  ORDER BY created_at DESC
  LIMIT 10;
  ```

**Acceptance Criteria:**
- ✅ Token reuse detected and entire family invalidated
- ✅ All tokens stored as hashes, never plaintext
- ✅ Audit log entries created for all token operations
- ✅ Token rotation works without breaking existing sessions

---

### 1.2 Enhanced Password Security ✅

**Automated Checks:**
- [ ] Run validation script - Phase 1.2 section
- [ ] Run SQL validation - password check

**Manual Tests:**
- [ ] **No Plaintext Passwords:**
  ```sql
  -- Check for plaintext passwords
  SELECT id, email, 
         CASE 
           WHEN password_hash ~ '^\$2[aby]?\$' THEN 'bcrypt'
           WHEN password_hash ~ '^\$argon2' THEN 'argon2'
           ELSE 'PLAINTEXT!'
         END as hash_type
  FROM users
  WHERE password_hash IS NOT NULL
  LIMIT 20;
  -- Should show NO 'PLAINTEXT!' entries
  ```

- [ ] **Password Strength Validation:**
  ```bash
  # Test weak password (should fail)
  curl -X POST http://localhost:3000/api/auth/register \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"123"}'
  # Should return 400 with password strength error
  
  # Test strong password (should succeed)
  curl -X POST http://localhost:3000/api/auth/register \
    -H "Content-Type: application/json" \
    -d '{"email":"test2@example.com","password":"Str0ng!P@ssw0rd"}'
  ```

**Acceptance Criteria:**
- ✅ Zero plaintext passwords in database
- ✅ Password strength validation enforced
- ✅ Both bcrypt and argon2 hashes supported

---

### 1.3 Role-Based Access Control (RBAC) ✅

**Automated Checks:**
- [ ] Run validation script - Phase 1.3 section
- [ ] Run SQL validation - role column check

**Manual Tests:**
- [ ] **Role Hierarchy:**
  ```bash
  # Test admin endpoint as regular user (should fail)
  curl -X GET http://localhost:3000/api/admin/users \
    -H "Authorization: Bearer <user_token>"
  # Should return 403 Forbidden
  
  # Test as admin (should succeed)
  curl -X GET http://localhost:3000/api/admin/users \
    -H "Authorization: Bearer <admin_token>"
  # Should return 200 with user list
  ```

- [ ] **Role Middleware:**
  ```typescript
  // Check middleware exists and works
  // Test in Postman/Insomnia with different role tokens
  ```

**Acceptance Criteria:**
- ✅ Role hierarchy enforced consistently
- ✅ Middleware correctly checks permissions
- ✅ Room-level roles work alongside global roles

---

### 1.4 Brute-Force Protection Enhancement ✅

**Automated Checks:**
- [ ] Run validation script - Phase 1.4 section
- [ ] Check Redis connection

**Manual Tests:**
- [ ] **Rate Limiting (5/min per IP):**
  ```bash
  # Try 6 login attempts rapidly (should lock after 5)
  for i in {1..6}; do
    curl -X POST http://localhost:3000/api/auth/login \
      -H "Content-Type: application/json" \
      -d '{"email":"test@example.com","password":"wrong"}'
    echo ""
  done
  # 6th attempt should return 429 Too Many Requests
  ```

- [ ] **CAPTCHA After 3 Failures:**
  ```bash
  # After 3 failed attempts, login should require CAPTCHA
  curl -X POST http://localhost:3000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"wrong","captchaToken":"<token>"}'
  # Should require captchaToken after 3 failures
  ```

- [ ] **Account Lockout After 5 Failures:**
  ```bash
  # After 5 failures, account should be locked for 15 minutes
  # Check Redis for lockout key
  redis-cli GET "login_attempts:<user_id>"
  # Should show lockedUntil timestamp
  ```

**Acceptance Criteria:**
- ✅ Rate limiting works across multiple server instances
- ✅ CAPTCHA required after 3 failed attempts
- ✅ Account lockout after 5 failures
- ✅ No false positives blocking legitimate users

---

### 1.5 HTTPS/TLS Enforcement ✅

**Automated Checks:**
- [ ] Run validation script - Phase 1.5 section

**Manual Tests:**
- [ ] **HSTS Headers:**
  ```bash
  # Check HSTS headers in production
  curl -I https://your-domain.com/api/health
  # Should include: Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
  ```

- [ ] **HTTPS Redirect:**
  ```bash
  # In production, HTTP should redirect to HTTPS
  curl -I http://your-domain.com/api/health
  # Should return 301 or 308 redirect to HTTPS
  ```

- [ ] **Security.txt:**
  ```bash
  # Check security.txt file
  curl https://your-domain.com/.well-known/security.txt
  # Should return security contact information
  ```

**Acceptance Criteria:**
- ✅ HSTS headers present in all responses
- ✅ HTTP requests redirected to HTTPS in production
- ✅ Security.txt accessible and properly formatted

---

## Phase 2: WebSocket & Messaging Optimization

### 2.1 Message Rate Limiting ✅

**Automated Checks:**
- [ ] Run validation script - Phase 2.1 section

**Manual Tests:**
- [ ] **15 Messages/30 Seconds Limit:**
  ```javascript
  // Connect WebSocket and send 16 messages rapidly
  const ws = new WebSocket('ws://localhost:3000');
  ws.onopen = () => {
    for (let i = 0; i < 16; i++) {
      ws.send(JSON.stringify({
        type: 'message',
        roomId: 'test-room',
        content: `Message ${i}`
      }));
    }
  };
  // 16th message should return rate limit error
  ```

- [ ] **Tier-Based Limits:**
  ```bash
  # Test with different user tiers
  # Free tier: 15/30s
  # Pro tier: 50/30s
  # Team tier: 200/30s
  ```

**Acceptance Criteria:**
- ✅ Rate limits enforced per user
- ✅ Tier-based limits work correctly
- ✅ Sliding window resets properly

---

### 2.2 Connection Health & Scaling ✅

**Automated Checks:**
- [ ] Run validation script - Phase 2.2 section

**Manual Tests:**
- [ ] **Idle Timeout (5 minutes):**
  ```javascript
  // Connect WebSocket and leave idle
  const ws = new WebSocket('ws://localhost:3000');
  // After 5 minutes of inactivity, connection should close
  ```

- [ ] **Ping/Pong:**
  ```javascript
  // Check ping/pong messages in WebSocket
  ws.on('pong', () => {
    console.log('Received pong');
  });
  ```

**Acceptance Criteria:**
- ✅ Idle connections closed after timeout
- ✅ Reconnection backoff prevents server overload
- ✅ Connection quality tracked and logged

---

### 2.3 Delivery Acknowledgements ✅

**Automated Checks:**
- [ ] Run validation script - Phase 2.3 section
- [ ] Run SQL validation - message_id and delivery_status columns

**Manual Tests:**
- [ ] **Message IDs:**
  ```javascript
  // Send message and verify it has message_id
  ws.send(JSON.stringify({
    type: 'message',
    roomId: 'test-room',
    content: 'Test message'
  }));
  
  // Response should include message_id (UUID)
  ```

- [ ] **Delivery Status:**
  ```sql
  -- Check delivery status tracking
  SELECT id, message_id, delivery_status, created_at
  FROM messages
  ORDER BY created_at DESC
  LIMIT 10;
  -- Should show: pending, delivered, or failed
  ```

- [ ] **Retry Logic:**
  ```javascript
  // Send message and don't acknowledge
  // After 5 seconds, message should retry
  // After 3 retries, status should be 'failed'
  ```

**Acceptance Criteria:**
- ✅ Message IDs generated and tracked
- ✅ Delivery status updated on ack receipt
- ✅ Failed messages retried automatically

---

### 2.4 WebSocket Scaling ✅

**Automated Checks:**
- [ ] Run validation script - Phase 2.4 section

**Manual Tests:**
- [ ] **Room Connection Limits (1000 max):**
  ```javascript
  // Try to connect 1001 users to same room
  // 1001st connection should be rejected gracefully
  ```

- [ ] **Redis Pub/Sub:**
  ```bash
  # Check Redis pub/sub channels
  redis-cli PUBSUB CHANNELS
  # Should show WebSocket channels
  ```

- [ ] **Cross-Instance Broadcasting:**
  ```bash
  # Start two server instances
  # Send message from instance 1
  # Verify it's received on instance 2
  ```

**Acceptance Criteria:**
- ✅ Room connection limits enforced
- ✅ Multiple server instances can handle same room
- ✅ Messages broadcast across all instances

---

## Phase 3: Database & Performance Optimization

### 3.1 Performance Indexes ✅

**Automated Checks:**
- [ ] Run validation script - Phase 3.1 section
- [ ] Run SQL validation - index checks

**Manual Tests:**
- [ ] **Query Performance:**
  ```sql
  -- Test query performance with EXPLAIN ANALYZE
  EXPLAIN ANALYZE
  SELECT * FROM messages
  WHERE sender_id = 'user-123'
    AND room_id = 'room-456'
  ORDER BY created_at DESC
  LIMIT 50;
  -- Execution time should be < 100ms
  ```

- [ ] **Index Usage:**
  ```sql
  -- Check index usage statistics
  SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
  FROM pg_stat_user_indexes
  WHERE tablename IN ('messages', 'conversation_participants')
  ORDER BY idx_scan DESC;
  ```

**Acceptance Criteria:**
- ✅ All critical indexes created
- ✅ Query execution time < 100ms for common queries
- ✅ Index usage monitored and optimized

---

### 3.2 Query Pagination ✅

**Automated Checks:**
- [ ] Run validation script - Phase 3.2 section

**Manual Tests:**
- [ ] **Cursor-Based Pagination:**
  ```bash
  # Test pagination endpoint
  curl "http://localhost:3000/api/messages?cursor=<timestamp>&limit=50"
  # Response should include: data, next_cursor, has_more
  ```

- [ ] **Limit Validation:**
  ```bash
  # Test max limit (should cap at 100)
  curl "http://localhost:3000/api/messages?limit=200"
  # Should return max 100 items
  ```

- [ ] **Pagination Metadata:**
  ```json
  {
    "data": [...],
    "pagination": {
      "has_more": true,
      "next_cursor": "2025-01-15T10:30:00Z",
      "total": null  // or count if available
    }
  }
  ```

**Acceptance Criteria:**
- ✅ Cursor-based pagination works for all list endpoints
- ✅ Limit enforced (max 100 per page)
- ✅ Pagination metadata included in responses

---

### 3.3 Message Archival ✅

**Automated Checks:**
- [ ] Run validation script - Phase 3.3 section
- [ ] Run SQL validation - message_archives table

**Manual Tests:**
- [ ] **Archive Old Messages:**
  ```sql
  -- Check for messages older than 90 days
  SELECT COUNT(*) as old_messages
  FROM messages
  WHERE created_at < NOW() - INTERVAL '90 days';
  
  -- Check archived messages
  SELECT COUNT(*) as archived
  FROM message_archives;
  ```

- [ ] **Archive Encryption:**
  ```sql
  -- Check if archives are encrypted
  SELECT id, encrypted_data, checksum
  FROM message_archives
  LIMIT 5;
  -- encrypted_data should be encrypted, not plaintext
  ```

- [ ] **Retrieval API:**
  ```bash
  # Test archive retrieval endpoint
  curl "http://localhost:3000/api/archives/messages?date=2024-01-01"
  # Should return archived messages
  ```

**Acceptance Criteria:**
- ✅ Messages archived after 90 days
- ✅ Archives encrypted at rest
- ✅ Archived messages retrievable via API

---

### 3.4 Redis Caching ✅

**Automated Checks:**
- [ ] Run validation script - Phase 3.4 section

**Manual Tests:**
- [ ] **Cache Functionality:**
  ```bash
  # Check Redis cache keys
  redis-cli KEYS "cache:*"
  # Should show cached data
  
  # Check cache TTLs
  redis-cli TTL "cache:user:123"
  # Should show remaining TTL
  ```

- [ ] **Cache Invalidation:**
  ```bash
  # Update data and verify cache is invalidated
  curl -X PUT http://localhost:3000/api/users/123 \
    -H "Authorization: Bearer <token>" \
    -d '{"name":"Updated"}'
  
  # Cache should be cleared
  redis-cli GET "cache:user:123"
  # Should return null or updated value
  ```

- [ ] **Cache Metrics:**
  ```bash
  # Check Prometheus metrics for cache hit/miss rates
  curl http://localhost:3000/metrics | grep cache
  # Should show cache_hits, cache_misses, cache_size
  ```

**Acceptance Criteria:**
- ✅ Hot data cached in Redis
- ✅ Cache invalidation works correctly
- ✅ Cache metrics tracked

---

## Summary

After completing all checks:

1. **Review automated validation results:**
   ```bash
   cat validation-results-phases-1-3.json
   ```

2. **Check SQL validation output:**
   ```bash
   psql $DATABASE_URL -f sql/validate-phases-1-3.sql > validation-sql-output.txt
   ```

3. **Document any issues found:**
   - Create issues in your issue tracker
   - Note which acceptance criteria failed
   - Include test results and error messages

4. **Mark phases as complete:**
   - Update BUILD.plan with completion status
   - Update this checklist with completion dates

---

**Last Updated:** 2025-01-XX  
**Validated By:** _________________  
**Status:** ⬜ In Progress | ⬜ Complete | ⬜ Blocked

