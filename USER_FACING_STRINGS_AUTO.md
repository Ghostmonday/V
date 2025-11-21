# User-Facing Strings - Automated Extraction
**Total Categories:** 20
**Total Files Scanned:** 101


## Admin

### `src/routes/admin-api-routes.ts`
**Found 2 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 76 | Demo data seeded successfully | message: 'Demo data seeded successfully', |
| 159 | Rate limit exceeded for this room | return res.status(429).json({ error: 'Rate limit exceeded for this room' }); |

## Authentication

### `src/middleware/auth/admin-auth-middleware.ts`
**Found 12 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 158 | Authentication required | res.status(401).json({ error: 'Authentication required' }); |
| 169 | Admin access required | res.status(403).json({ error: 'Admin access required' }); |
| 177 | Authorization check failed | res.status(500).json({ error: 'Authorization check failed' }); |
| 193 | Authentication required | res.status(401).json({ error: 'Authentication required' }); |
| 209 | Moderator access required | res.status(403).json({ error: 'Moderator access required' }); |
| 212 | Authorization check failed | res.status(500).json({ error: 'Authorization check failed' }); |
| 228 | Authentication required | res.status(401).json({ error: 'Authentication required' }); |
| 239 | Owner access required | res.status(403).json({ error: 'Owner access required' }); |
| 246 | Authorization check failed | res.status(500).json({ error: 'Authorization check failed' }); |
| 260 | Authentication required | res.status(401).json({ error: 'Authentication required' }); |
| 273 | Permission required: ${permission} | res.status(403).json({ error: `Permission required: ${permission}` }); |
| 280 | Authorization check failed | res.status(500).json({ error: 'Authorization check failed' }); |

### `src/middleware/auth/supabase-auth-middleware.ts`
**Found 6 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 64 | Server configuration error | return res.status(500).json({ error: 'Server configuration error' }); |
| 76 | Supabase JWT verification failed | message: 'Supabase JWT verification failed', |
| 78 | User not found | data: { error: authError?.message \|\| 'User not found' }, |
| 80 | Invalid token | return res.status(401).json({ error: 'Invalid token' }); |
| 94 | Supabase JWT verification error | message: 'Supabase JWT verification error', |
| 98 | Invalid token | return res.status(401).json({ error: 'Invalid token' }); |

### `src/routes/auth-api-routes.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 20 | Username and password are required | return res.status(400).json({ error: 'Username and password are required' }); |
| 29 | Authentication failed | res.status(401).json({ error: error.message \|\| 'Authentication failed' }); |
| 42 | Username and password are required | return res.status(400).json({ error: 'Username and password are required' }); |
| 51 | Registration failed | res.status(400).json({ error: error.message \|\| 'Registration failed' }); |

### `src/services/user-authentication-service.ts`
**Found 25 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 71 | ENCRYPTION_MASTER_KEY not found in vault or environment | throw new Error('ENCRYPTION_MASTER_KEY not found in vault or environment'); |
| 113 | Encryption failed | logError('Encryption failed', error instanceof Error ? error : new Error(String(error))); |
| 114 | Failed to encrypt sensitive data | throw new Error('Failed to encrypt sensitive data'); |
| 141 | Decryption failed | logError('Decryption failed', error instanceof Error ? error : new Error(String(error))); |
| 142 | Failed to decrypt sensitive data | throw new Error('Failed to decrypt sensitive data'); |
| 191 | Invalid credentials | if (error \|\| !data.user) throw new Error('Invalid credentials'); |
| 204 | JWT_SECRET is not set | throw new Error('JWT_SECRET is not set'); |
| 247 | Apple authentication token is required | throw new Error('Apple authentication token is required'); |
| 273 | JWT_SECRET not found in vault | throw new Error('JWT_SECRET not found in vault'); |
| 295 | Failed to verify Apple authentication token | error instanceof Error ? error.message : 'Failed to verify Apple authentication token' |
| 336 | Invalid username format | throw new Error('Invalid username format'); |
| 345 | Invalid username or password | throw new Error('Invalid username or password'); |
| 381 | Invalid username or password | throw new Error('Invalid username or password'); |
| 385 | Invalid username or password | throw new Error('Invalid username or password'); |
| 391 | JWT_SECRET not found in vault | throw new Error('JWT_SECRET not found in vault'); |
| 402 | Login failed | throw new Error(error instanceof Error ? error.message : 'Login failed'); |
| 420 | Password does not meet requirements: ${passwordStrength.errors.join(', ')} | //   throw new Error(`Password does not meet requirements: ${passwordStrength.errors.join(', ')}`); |
| 425 | Username can only contain letters, numbers, underscores, and hyphens | throw new Error('Username can only contain letters, numbers, underscores, and hyphens'); |
| 431 | Username already exists | throw new Error('Username already exists'); |
| 443 | Failed to hash password | throw new Error('Failed to hash password'); |
| 460 | JWT_SECRET not found in vault | throw new Error('JWT_SECRET not found in vault'); |
| 467 | Registration failed | logError('Registration failed', error instanceof Error ? error : new Error(String(error))); |
| 468 | Registration failed | throw new Error(error instanceof Error ? error.message : 'Registration failed'); |
| 480 | JWT_SECRET not found in vault | throw new Error('JWT_SECRET not found in vault'); |
| 485 | Invalid token | throw new Error('Invalid token'); |

## Error Handling

### `src/middleware/error-middleware.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 29 | Validation Error | message = 'Validation Error'; |
| 36 | Duplicate entry | message = 'Duplicate entry'; |
| 39 | Invalid reference | message = 'Invalid reference'; |
| 108 | Internal Server Error | error: statusCode >= 500 ? 'Internal Server Error' : message, |

## File Management

### `src/middleware/security/file-upload-security-middleware.ts`
**Found 2 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 38 | Invalid file type | error: 'Invalid file type', |
| 54 | File too large | error: 'File too large', |

### `src/services/file-storage-service.ts`
**Found 9 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 20 | AWS credentials not found in vault | throw new Error('AWS credentials not found in vault'); |
| 50 | No file provided | throw new Error('No file provided'); |
| 93 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 94 | File upload failed | logError('File upload failed', error instanceof Error ? error : new Error(errorMessage)); |
| 95 | Failed to upload file | throw new Error(errorMessage \|\| 'Failed to upload file'); |
| 113 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 136 | Failed to get file URL | throw new Error(error.message \|\| 'Failed to get file URL'); |
| 174 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 175 | File deletion failed | logError('File deletion failed', error instanceof Error ? error : new Error(errorMessage)); |

## Gamification

### `src/routes/gamification-api-routes.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 17 | Failed to fetch user progress | res.status(500).json({ error: 'Failed to fetch user progress' }); |

## Messaging

### `src/routes/chat-room-config-api-routes.ts`
**Found 14 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 36 | Room not found | return res.status(404).json({ error: 'Room not found' }); |
| 42 | Permission denied | return res.status(403).json({ error: 'Permission denied' }); |
| 53 | Failed to get room config | res.status(500).json({ error: 'Failed to get room config' }); |
| 80 | Room not found | return res.status(404).json({ error: 'Room not found' }); |
| 97 | Enterprise subscription required for AI moderation | error: 'Enterprise subscription required for AI moderation', |
| 162 | Room not found | return res.status(404).json({ error: 'Room not found' }); |
| 172 | Enterprise subscription required for AI moderation | error: 'Enterprise subscription required for AI moderation', |
| 230 | Room not found | return res.status(404).json({ error: 'Room not found' }); |
| 264 | Failed to get moderation thresholds | res.status(500).json({ error: 'Failed to get moderation thresholds' }); |
| 288 | warn_threshold must be between 0 and 1 | return res.status(400).json({ error: 'warn_threshold must be between 0 and 1' }); |
| 291 | block_threshold must be between 0 and 1 | return res.status(400).json({ error: 'block_threshold must be between 0 and 1' }); |
| 298 | block_threshold must be >= warn_threshold | return res.status(400).json({ error: 'block_threshold must be >= warn_threshold' }); |
| 309 | Room not found | return res.status(404).json({ error: 'Room not found' }); |
| 321 | Permission denied - only room owner or admin can set thresholds | .json({ error: 'Permission denied - only room owner or admin can set thresholds' }); |

### `src/routes/message-api-routes.ts`
**Found 3 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 32 | Message queued for processing | message: 'Message queued for processing', |
| 152 | Invalid message_id | res.status(400).json({ error: 'Invalid message_id' }); |
| 159 | Archived message not found | res.status(404).json({ error: 'Archived message not found' }); |

### `src/services/message-archival-service.ts`
**Found 13 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 106 | Invalid message structure for archiving | throw new Error('Invalid message structure for archiving'); |
| 130 | Archive encryption failed | throw new Error('Archive encryption failed'); |
| 134 | Archive checksum calculation failed | throw new Error('Archive checksum calculation failed'); |
| 169 | Message not found | return { success: false, error: 'Message not found' }; |
| 206 | Archive table not configured | return { success: false, error: 'Archive table not configured' }; |
| 224 | Archive failed | return { success: false, error: error.message \|\| 'Archive failed' }; |
| 235 | Invalid message ID format | throw new Error('Invalid message ID format'); |
| 251 | Invalid archive structure | throw new Error('Invalid archive structure'); |
| 266 | Archive integrity verification failed | throw new Error('Archive integrity verification failed'); |
| 274 | Archive decryption failed | throw new Error('Archive decryption failed'); |
| 282 | Invalid message data in archive | throw new Error('Invalid message data in archive'); |
| 321 | Batch query returned non-array result | throw new Error('Batch query returned non-array result'); |
| 334 | Failed to archive message ${message.id} | logWarning(`Failed to archive message ${message.id}`, { error: result.error }); |

### `src/services/message-controller-service.ts`
**Found 25 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 29 | Invalid message_id | res.status(400).json({ error: 'Invalid message_id' }); |
| 34 | Invalid emoji | res.status(400).json({ error: 'Invalid emoji' }); |
| 39 | Invalid user_id | res.status(400).json({ error: 'Invalid user_id' }); |
| 52 | Message not found | res.status(404).json({ error: 'Message not found' }); |
| 164 | Failed to add reaction | res.status(500).json({ error: 'Failed to add reaction' }); |
| 177 | Invalid parent_message_id | res.status(400).json({ error: 'Invalid parent_message_id' }); |
| 182 | Unauthorized: Missing user_id | res.status(401).json({ error: 'Unauthorized: Missing user_id' }); |
| 195 | Parent message not found | res.status(404).json({ error: 'Parent message not found' }); |
| 260 | Failed to create thread | res.status(500).json({ error: 'Failed to create thread' }); |
| 275 | Invalid thread_id | res.status(400).json({ error: 'Invalid thread_id' }); |
| 284 | *, parent_message:messages(*) | .select('*, parent_message:messages(*)') |
| 306 | Thread not found | res.status(404).json({ error: 'Thread not found' }); |
| 359 | Failed to fetch thread | res.status(500).json({ error: 'Failed to fetch thread' }); |
| 374 | Invalid room_id | res.status(400).json({ error: 'Invalid room_id' }); |
| 444 | Failed to fetch room threads | res.status(500).json({ error: 'Failed to fetch room threads' }); |
| 457 | Invalid message_id | res.status(400).json({ error: 'Invalid message_id' }); |
| 462 | Invalid content | res.status(400).json({ error: 'Invalid content' }); |
| 479 | Message not found | res.status(404).json({ error: 'Message not found' }); |
| 485 | Not authorized to edit this message | res.status(403).json({ error: 'Not authorized to edit this message' }); |
| 506 | Message can only be edited within 24 hours | res.status(400).json({ error: 'Message can only be edited within 24 hours' }); |
| 545 | Failed to edit message | res.status(500).json({ error: 'Failed to edit message' }); |
| 558 | Invalid message_id | res.status(400).json({ error: 'Invalid message_id' }); |
| 575 | Message not found | res.status(404).json({ error: 'Message not found' }); |
| 641 | Invalid search query | res.status(400).json({ error: 'Invalid search query' }); |
| 722 | Failed to search messages | res.status(500).json({ error: 'Failed to search messages' }); |

### `src/services/message-delivery-service.ts`
**Found 3 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 64 | Invalid message ID format | throw new Error('Invalid message ID format'); |
| 69 | Invalid user ID format | throw new Error('Invalid user ID format'); |
| 240 | Invalid message ID format | throw new Error('Invalid message ID format'); |

### `src/services/message-queue-service.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 118 | Message queue is overloaded. Please try again later. | throw new Error('Message queue is overloaded. Please try again later.'); // Load spike: legitimate u |

### `src/services/message-service.ts`
**Found 7 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 77 | Invalid roomId format | throw new Error('Invalid roomId format'); |
| 86 | Invalid senderId format | throw new Error('Invalid senderId format'); |
| 92 | You are temporarily muted in this room | throw new Error('You are temporarily muted in this room'); |
| 155 | Room requires end-to-end encryption. Message payload must be encrypted. | throw new Error('Room requires end-to-end encryption. Message payload must be encrypted.'); |
| 181 | Failed to prepare message content for storage | throw new Error('Failed to prepare message content for storage'); |
| 254 | Failed to send message | throw new Error(error.message \|\| 'Failed to send message'); // DB insert may have succeeded - partia |
| 316 | Failed to get messages | throw new Error(error.message \|\| 'Failed to get messages'); |

## Moderation

### `src/middleware/security/moderation-middleware.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 18 | Content must be a string | return res.status(400).json({ error: 'Content must be a string' }); |
| 24 | Content exceeds maximum length | return res.status(400).json({ error: 'Content exceeds maximum length' }); |
| 51 | Content violates community guidelines | return res.status(400).json({ error: 'Content violates community guidelines' }); |
| 70 | Content appears to be spam | return res.status(400).json({ error: 'Content appears to be spam' }); |

### `src/routes/admin-moderation-api-routes.ts`
**Found 6 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 40 | Failed to get flagged messages | res.status(500).json({ error: 'Failed to get flagged messages' }); |
| 55 | Authentication required | return res.status(401).json({ error: 'Authentication required' }); |
| 59 | Invalid action | return res.status(400).json({ error: 'Invalid action' }); |
| 65 | Flag not found | return res.status(404).json({ error: 'Flag not found' }); |
| 70 | Failed to review flag | res.status(500).json({ error: 'Failed to review flag' }); |
| 104 | Failed to get moderation stats | res.status(500).json({ error: 'Failed to get moderation stats' }); |

### `src/routes/moderation-api-routes.ts`
**Found 10 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 35 | message_id and room_id are required | return res.status(400).json({ error: 'message_id and room_id are required' }); |
| 40 | Invalid reason. Must be one of: toxicity, spam, harassment, inappropriate, other | error: 'Invalid reason. Must be one of: toxicity, spam, harassment, inappropriate, other', |
| 53 | Message not found | return res.status(404).json({ error: 'Message not found' }); |
| 65 | You must be a member of this room to flag messages | return res.status(403).json({ error: 'You must be a member of this room to flag messages' }); |
| 70 | You cannot flag your own messages | return res.status(400).json({ error: 'You cannot flag your own messages' }); |
| 82 | You have already flagged this message | return res.status(409).json({ error: 'You have already flagged this message' }); |
| 101 | Failed to flag message | return res.status(500).json({ error: 'Failed to flag message' }); |
| 109 | Message flagged successfully. It will be reviewed by moderators. | message: 'Message flagged successfully. It will be reviewed by moderators.', |
| 113 | Failed to flag message | res.status(500).json({ error: 'Failed to flag message' }); |
| 153 | Failed to get flags | res.status(500).json({ error: 'Failed to get flags' }); |

### `src/services/moderation-service.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 134 | Invalid JSON response | throw new Error('Invalid JSON response'); |

## Notifications

### `src/middleware/monitoring/error-alerting-middleware.ts`
**Found 2 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 42 | 🚨 VibeZ Alert: ${message} | text: `🚨 VibeZ Alert: ${message}`, |
| 153 | High error rate detected: ${errorKey} (${count} errors/min) | const message = `High error rate detected: ${errorKey} (${count} errors/min)`; |

### `src/routes/notify-api-routes.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 13 | Notify failed | res.status(500).json({ error: 'Notify failed' }); |

### `src/services/notifications-service.ts`
**Found 15 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 14 | VAPID keys not found - push notifications disabled | logInfo('VAPID keys not found - push notifications disabled'); |
| 18 | notifications:stream | const NOTIFICATION_STREAM = 'notifications:stream'; |
| 19 | notification-workers | const NOTIFICATION_GROUP = 'notification-workers'; |
| 55 | Failed to enqueue notification via stream, using list fallback | logError('Failed to enqueue notification via stream, using list fallback', error); |
| 56 | notifications:${userId} | await redis.rpush(`notifications:${userId}`, JSON.stringify(payload)); |
| 111 | Notification sent to user ${userId} | logInfo(`Notification sent to user ${userId}`); |
| 113 | Failed to send notification to ${sub.endpoint} | logError(`Failed to send notification to ${sub.endpoint}`, err); |
| 129 | Error processing notification | logError('Error processing notification', error); |
| 140 | Notification worker error | logError('Notification worker error', error); |
| 150 | notifications:* | const [nextCursor, keys] = await redis.scan(cursor, 'MATCH', 'notifications:*', 'COUNT', 10); |
| 153 | notifications:stream | if (key.startsWith('notifications:stream')) continue; // Skip stream keys |
| 171 | Failed to send notification | logError(`Failed to send notification`, err); |
| 177 | Notification list fallback error | logError('Notification list fallback error', error); |
| 183 | Failed to initialize notification stream | logError('Failed to initialize notification stream', err); |
| 189 | Notification queue processing error | logError('Notification queue processing error', err); |

## Other

### `src/config/database-config.ts`
**Found 2 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 25 | NEXT_PUBLIC_SUPABASE_URL is required | throw new Error('NEXT_PUBLIC_SUPABASE_URL is required'); |
| 30 | SUPABASE_SERVICE_ROLE_KEY is required | throw new Error('SUPABASE_SERVICE_ROLE_KEY is required'); |

### `src/config/llm-params-config.ts`
**Found 9 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 151 | AI models used for different operations | description: 'AI models used for different operations', |
| 171 | Controls randomness and creativity in LLM outputs | description: 'Controls randomness and creativity in LLM outputs', |
| 194 | Response length and cost management | description: 'Response length and cost management', |
| 223 | API call frequency and abuse prevention | description: 'API call frequency and abuse prevention', |
| 252 | Content filtering and moderation sensitivity | description: 'Content filtering and moderation sensitivity', |
| 315 | Operation performance and resource limits | description: 'Operation performance and resource limits', |
| 341 | System optimization parameters | description: 'System optimization parameters', |
| 364 | Vector similarity search configuration | description: 'Vector similarity search configuration', |
| 384 | Hours when AI automation is disabled | description: 'Hours when AI automation is disabled', |

### `src/config/redis-cluster-config.ts`
**Found 7 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 66 | REDIS_CLUSTER_NODES is required when REDIS_MODE=cluster | throw new Error('REDIS_CLUSTER_NODES is required when REDIS_MODE=cluster'); |
| 99 | REDIS_SENTINELS is required when REDIS_MODE=sentinel | throw new Error('REDIS_SENTINELS is required when REDIS_MODE=sentinel'); |
| 127 | Invalid REDIS_MODE: ${mode}. Must be 'single', 'cluster', or 'sentinel' | throw new Error(`Invalid REDIS_MODE: ${mode}. Must be 'single', 'cluster', or 'sentinel'`); |
| 154 | Cluster nodes are required for cluster mode | throw new Error('Cluster nodes are required for cluster mode'); |
| 175 | Sentinels are required for sentinel mode | throw new Error('Sentinels are required for sentinel mode'); |
| 195 | Unsupported Redis mode: ${redisConfig.mode} | throw new Error(`Unsupported Redis mode: ${redisConfig.mode}`); |
| 265 | Redis cluster node error: ${node.options.host}:${node.options.port} | logError(`Redis cluster node error: ${node.options.host}:${node.options.port}`, err); |

### `src/config/redis-cluster.ts`
**Found 9 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 66 | REDIS_CLUSTER_NODES is required when REDIS_MODE=cluster | throw new Error('REDIS_CLUSTER_NODES is required when REDIS_MODE=cluster'); |
| 99 | REDIS_SENTINELS is required when REDIS_MODE=sentinel | throw new Error('REDIS_SENTINELS is required when REDIS_MODE=sentinel'); |
| 127 | Invalid REDIS_MODE: ${mode}. Must be 'single', 'cluster', or 'sentinel' | throw new Error(`Invalid REDIS_MODE: ${mode}. Must be 'single', 'cluster', or 'sentinel'`); |
| 154 | Cluster nodes are required for cluster mode | throw new Error('Cluster nodes are required for cluster mode'); |
| 175 | Sentinels are required for sentinel mode | throw new Error('Sentinels are required for sentinel mode'); |
| 195 | Unsupported Redis mode: ${redisConfig.mode} | throw new Error(`Unsupported Redis mode: ${redisConfig.mode}`); |
| 265 | Redis cluster node error: ${node.options.host}:${node.options.port} | logError(`Redis cluster node error: ${node.options.host}:${node.options.port}`, err); |
| 286 | Redis health check failed | logError('Redis health check failed', error instanceof Error ? error : new Error(String(error))); |
| 299 | Error closing Redis client | logError('Error closing Redis client', error instanceof Error ? error : new Error(String(error))); |

### `src/config/redis-failover.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 48 | Redis health check error | logError('Redis health check error', error instanceof Error ? error : new Error(String(error))); |

### `src/config/redis-streams-config.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 327 | Failed to trim stream | logError('Failed to trim stream', error instanceof Error ? error : new Error(String(error))); |

### `src/http-websocket-server.ts`
**Found 2 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 424 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 426 | Failed to fetch stats | error: 'Failed to fetch stats', |

### `src/jobs/data-retention-cron-job.ts`
**Found 5 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 137 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 187 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 237 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 294 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 368 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |

### `src/jobs/partition-management-cron-job.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 147 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |

### `src/middleware/circuit-breaker-middleware.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 58 | Circuit breaker ${this.name} is OPEN. Service unavailable. | throw new Error(`Circuit breaker ${this.name} is OPEN. Service unavailable.`); |

### `src/middleware/database-transaction-middleware.ts`
**Found 8 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 56 | Transaction requires at least one operation | throw new Error('Transaction requires at least one operation'); |
| 61 | Transaction failed after ${MAX_TRANSACTION_RETRIES} retries | throw new Error(`Transaction failed after ${MAX_TRANSACTION_RETRIES} retries`); |
| 73 | Invalid operation: must be a function | throw new Error('Invalid operation: must be a function'); |
| 143 | Invalid transaction data | throw new Error('Invalid transaction data'); |
| 162 | Message created but missing ID | throw new Error('Message created but missing ID'); |
| 170 | Invalid message for receipt creation | throw new Error('Invalid message for receipt creation'); |
| 190 | Receipt created but missing ID | throw new Error('Receipt created but missing ID'); |
| 199 | Transaction completed but result structure invalid | throw new Error('Transaction completed but result structure invalid'); |

### `src/routes/bandwidth-api-routes.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 39 | Invalid mode. Must be auto, low, or high | return res.status(400).json({ error: 'Invalid mode. Must be auto, low, or high' }); |

### `src/routes/health-api-routes.ts`
**Found 3 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 40 | Failed to get cache metrics | res.status(500).json({ error: 'Failed to get cache metrics' }); |
| 59 | Failed to get shard health | res.status(500).json({ error: 'Failed to get shard health' }); |
| 78 | Failed to get partition health | res.status(500).json({ error: 'Failed to get partition health' }); |

### `src/routes/invite-api-routes.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 19 | Room ID is required | res.status(400).json({ error: 'Room ID is required' }); |
| 28 | Failed to create invite | res.status(500).json({ error: 'Failed to create invite' }); |
| 41 | Invalid or expired invite | res.status(400).json({ error: 'Invalid or expired invite' }); |
| 49 | Failed to use invite | res.status(500).json({ error: 'Failed to use invite' }); |

### `src/routes/nicknames-api-routes.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 24 | nickname is required | return res.status(400).json({ error: 'nickname is required' }); |

### `src/routes/reactions-api-routes.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 13 | message_id and emoji are required | return res.status(400).json({ error: 'message_id and emoji are required' }); |
| 17 | action must be "add" or "remove" | return res.status(400).json({ error: 'action must be "add" or "remove"' }); |
| 22 | Invalid emoji format | return res.status(400).json({ error: 'Invalid emoji format' }); |
| 33 | Message not found | return res.status(404).json({ error: 'Message not found' }); |

### `src/routes/read-receipts-api-routes.ts`
**Found 8 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 30 | message_id is required | return res.status(400).json({ error: 'message_id is required' }); |
| 41 | Failed to mark message as read | res.status(500).json({ error: 'Failed to mark message as read', message: error.message }); |
| 55 | message_id is required | return res.status(400).json({ error: 'message_id is required' }); |
| 66 | Failed to mark message as delivered | res.status(500).json({ error: 'Failed to mark message as delivered', message: error.message }); |
| 80 | message_ids array is required | return res.status(400).json({ error: 'message_ids array is required' }); |
| 91 | Failed to mark messages as read | res.status(500).json({ error: 'Failed to mark messages as read', message: error.message }); |
| 106 | Failed to get read receipts | res.status(500).json({ error: 'Failed to get read receipts', message: error.message }); |
| 127 | Failed to get room read status | res.status(500).json({ error: 'Failed to get room read status', message: error.message }); |

### `src/routes/threads-api-routes.ts`
**Found 2 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 30 | Failed to create thread | res.status(500).json({ error: 'Failed to create thread' }); |
| 40 | Failed to get thread | res.status(500).json({ error: 'Failed to get thread' }); |

### `src/services/api-keys-service.ts`
**Found 3 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 51 | API key not found: ${keyName} | throw new Error(`API key not found: ${keyName}`); |
| 55 | API key not found: ${keyName} | throw new Error(`API key not found: ${keyName}`); |
| 89 | Failed to retrieve keys for category: ${category} | throw new Error(`Failed to retrieve keys for category: ${category}`); |

### `src/services/apple-jwks-verifier.ts`
**Found 3 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 22 | Apple token is required | throw new Error('Apple token is required'); |
| 31 | APPLE_SERVICE_ID or APPLE_CLIENT_ID must be set in vault | throw new Error('APPLE_SERVICE_ID or APPLE_CLIENT_ID must be set in vault'); |
| 48 | Failed to verify Apple token | throw new Error(error instanceof Error ? error.message : 'Failed to verify Apple token'); |

### `src/services/bot-invite-service.ts`
**Found 6 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 84 | Invite not found | throw new Error('Invite not found'); |
| 88 | Invite already used or expired | throw new Error('Invite already used or expired'); |
| 94 | Invite has expired | throw new Error('Invite has expired'); |
| 128 | Sends welcome messages to new members | description: 'Sends welcome messages to new members', |
| 130 | Welcome to the room! | welcome_message: 'Welcome to the room!', |
| 137 | Automatically moderates messages | description: 'Automatically moderates messages', |

### `src/services/cache-service.ts`
**Found 3 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 37 | Cache get error | logError('Cache get error', error instanceof Error ? error : new Error(String(error))); |
| 69 | Cache set error | logError('Cache set error', error instanceof Error ? error : new Error(String(error))); |
| 100 | Cache invalidation error | logError('Cache invalidation error', error instanceof Error ? error : new Error(String(error))); |

### `src/services/compression-service.ts`
**Found 2 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 122 | Failed to upload to Supabase Storage: ${error.message} | throw new Error(`Failed to upload to Supabase Storage: ${error.message}`); |
| 126 | Upload succeeded but no data returned | throw new Error('Upload succeeded but no data returned'); |

### `src/services/config-service.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 25 | Failed to get configuration | throw new Error(error.message \|\| 'Failed to get configuration'); // Error branch: DB timeout not cau |

### `src/services/connection-pool-monitor.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 107 | Database connection pool exhausted | const error = new Error('Database connection pool exhausted'); |

### `src/services/data-deletion-service.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 154 | Unexpected error: ${error.message} | errors.push(`Unexpected error: ${error.message}`); |

### `src/services/nickname-service.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 19 | Nickname must be 32 characters or less | throw new Error('Nickname must be 32 characters or less'); |

### `src/services/partition-management-service.ts`
**Found 7 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 48 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 49 | Partition rotation error | logError('Partition rotation error', error instanceof Error ? error : new Error(errorMessage)); |
| 111 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 126 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 127 | Partition cleanup error | logError('Partition cleanup error', error instanceof Error ? error : new Error(errorMessage)); |
| 177 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 196 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |

### `src/services/pfs-media-service.ts`
**Found 8 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 72 | Failed to generate ephemeral key pair for PFS | throw new Error('Failed to generate ephemeral key pair for PFS'); |
| 131 | Failed to derive shared secret for PFS | throw new Error('Failed to derive shared secret for PFS'); |
| 202 | Failed to create PFS call session | throw new Error('Failed to create PFS call session'); |
| 352 | Auth tag required for GCM mode | throw new Error('Auth tag required for GCM mode'); |
| 370 | Failed to encrypt media stream with PFS | throw new Error('Failed to encrypt media stream with PFS'); |
| 379 | Media stream encryption temporarily unavailable | throw new Error('Media stream encryption temporarily unavailable'); |
| 429 | Failed to decrypt media stream with PFS | throw new Error('Failed to decrypt media stream with PFS'); |
| 438 | Media stream decryption temporarily unavailable | throw new Error('Media stream decryption temporarily unavailable'); |

### `src/services/poll-service.ts`
**Found 5 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 87 | Poll not found | throw new Error('Poll not found'); |
| 91 | Poll is not active | throw new Error('Poll is not active'); |
| 97 | Poll has expired | throw new Error('Poll has expired'); |
| 110 | Already voted | throw new Error('Already voted'); |
| 157 | Poll not found | throw new Error('Poll not found'); |

### `src/services/query-optimization-service.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 33 | Invalid room ID format | throw new Error('Invalid room ID format'); |
| 42 | Invalid cursor format. Must be ISO timestamp. | throw new Error('Invalid cursor format. Must be ISO timestamp.'); |
| 47 | Invalid pagination direction. Must be "forward" or "backward". | throw new Error('Invalid pagination direction. Must be "forward" or "backward".'); |
| 78 | Query returned non-array result | throw new Error('Query returned non-array result'); |

### `src/services/sharding-service.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 119 | Failed to register shard | logError('Failed to register shard', error instanceof Error ? error : new Error(String(error))); |

### `src/services/usage-meter-service.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 137 | Failed to get usage | logError('Failed to get usage', error instanceof Error ? error : new Error(String(error))); |

### `src/services/usage-service.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 24 | Failed to track usage | logError('Failed to track usage', error instanceof Error ? error : new Error(String(error))); |

### `src/services/webhooks-service.ts`
**Found 8 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 110 | Failed to parse notification | 'Failed to parse notification', |
| 156 | App Store notification parsed | logInfo('App Store notification parsed', { |
| 165 | Failed to parse App Store notification | 'Failed to parse App Store notification', |
| 173 | Invalid notification format | res.status(400).json({ error: 'Invalid notification format', requestId }); |
| 179 | Missing required fields in notification | 'Missing required fields in notification', |
| 188 | Bad Request: Missing required fields | res.status(400).json({ error: 'Bad Request: Missing required fields', requestId }); |
| 272 | App Store webhook error | logError('App Store webhook error', error instanceof Error ? error : new Error(String(error)), { |
| 281 | Internal Server Error | error: 'Internal Server Error', |

### `src/services/zkp-service.ts`
**Found 2 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 132 | Failed to generate zero-knowledge proof | throw new Error('Failed to generate zero-knowledge proof'); |
| 351 | Verification error: ${error.message} | return { index, valid: false, errors: [`Verification error: ${error.message}`] }; |

### `src/shared/supabase-helpers-shared.ts`
**Found 10 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 49 | Failed to find record in ${table} | throw new Error(err.message \|\| `Failed to find record in ${table}`); |
| 97 | Invalid cursor format. Must be UUID or ISO timestamp. | throw new Error('Invalid cursor format. Must be UUID or ISO timestamp.'); |
| 120 | Invalid cursor column | throw new Error('Invalid cursor column'); |
| 154 | Query returned non-array result | throw new Error('Query returned non-array result'); |
| 198 | Failed to query ${table} | throw new Error(err.message \|\| `Failed to query ${table}`); |
| 239 | Failed to create record in ${table} | throw new Error(err.message \|\| `Failed to create record in ${table}`); |
| 308 | Supabase upsert failed for table: ${table} | message: `Supabase upsert failed for table: ${table}`, |
| 319 | Failed to upsert record in ${table} | throw new Error(err.message \|\| `Failed to upsert record in ${table}`); |
| 377 | Transaction failed | throw new Error(err.message \|\| 'Transaction failed'); |
| 416 | Transaction execution failed | throw new Error(err.message \|\| 'Transaction execution failed'); |

### `src/tests/__helpers__/test-setup.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 189 | Invalid credentials | error: { message: 'Invalid credentials' }, |

### `src/utils/app-error.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 15 | Bad Request | constructor(message = 'Bad Request') { |
| 33 | Not Found | constructor(message = 'Not Found') { |
| 45 | Too Many Requests | constructor(message = 'Too Many Requests') { |
| 51 | Internal Server Error | constructor(message = 'Internal Server Error') { |

### `src/utils/circuit-breaker-utils.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 58 | Circuit breaker is OPEN - service unavailable | throw new Error('Circuit breaker is OPEN - service unavailable'); |

### `src/utils/supabase-retry.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 71 | Max retries exceeded | return { data: null, error: { message: 'Max retries exceeded', code: 'TIMEOUT', details: '', hint: ' |

### `src/workers/sin-ai-worker.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 80 | DeepSeek API error: ${response.statusText} | throw new Error(`DeepSeek API error: ${response.statusText}`); |
| 86 | DeepSeek API call failed | logError('DeepSeek API call failed', error instanceof Error ? error : new Error(String(error))); |
| 111 | postSinMessage error | logError('postSinMessage error', error instanceof Error ? error : new Error(String(error))); |
| 165 | Sin worker error | logError('Sin worker error', error instanceof Error ? error : new Error(String(error))); |

### `src/ws/handlers/websocket-reactions-threads-handler.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 93 | Invalid reaction data | message: 'Invalid reaction data', |
| 108 | Failed to process reaction | message: 'Failed to process reaction', |
| 123 | Invalid thread data | message: 'Invalid thread data', |
| 135 | Failed to process thread creation | message: 'Failed to process thread creation', |

### `src/ws/websocket-gateway.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 561 | WebSocket error | logError('WebSocket error', error instanceof Error ? error : new Error(String(error)), { |

### `src/ws/websocket-utils.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 236 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 302 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 378 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |
| 410 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |

## Privacy

### `src/routes/privacy-api-routes.ts`
**Found 12 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 32 | Too many disclosure requests, please try again later | message: 'Too many disclosure requests, please try again later', |
| 56 | Invalid request body | error: 'Invalid request body', |
| 66 | Invalid verifierId format | error: 'Invalid verifierId format', |
| 80 | User not found | return res.status(404).json({ error: 'User not found' }); |
| 136 | Invalid batched request body | error: 'Invalid batched request body', |
| 173 | Invalid request body | error: 'Invalid request body', |
| 235 | Hardware acceleration unavailable - using software encryption | message: 'Hardware acceleration unavailable - using software encryption', |
| 244 | Failed to get encryption status | error: 'Failed to get encryption status', |
| 262 | Invalid userId format | return res.status(400).json({ error: 'Invalid userId format' }); |
| 269 | Forbidden: Cannot view other users' commitments | return res.status(403).json({ error: "Forbidden: Cannot view other users' commitments" }); |
| 283 | Failed to fetch commitments | return res.status(500).json({ error: 'Failed to fetch commitments' }); |
| 295 | Failed to get ZKP commitments | error: 'Failed to get ZKP commitments', |

## Rate Limiting

### `src/middleware/rate-limiting/express-rate-limit-middleware.ts`
**Found 16 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 32 | Too many requests from this IP, please try again later. | message: 'Too many requests from this IP, please try again later.', |
| 35 | Rate limit exceeded | error: 'Rate limit exceeded', |
| 36 | Too many requests, please try again later. | message: 'Too many requests, please try again later.', |
| 52 | Too many requests, please slow down. | message: 'Too many requests, please slow down.', |
| 55 | Rate limit exceeded | error: 'Rate limit exceeded', |
| 56 | Too many requests to this sensitive endpoint, please try again later. | message: 'Too many requests to this sensitive endpoint, please try again later.', |
| 99 | Rate limit exceeded for your subscription tier. | message: 'Rate limit exceeded for your subscription tier.', |
| 102 | Rate limit exceeded | error: 'Rate limit exceeded', |
| 103 | You have exceeded the rate limit for your subscription tier. | message: 'You have exceeded the rate limit for your subscription tier.', |
| 121 | User rate limit requires authentication | throw new Error('User rate limit requires authentication'); |
| 125 | Too many requests from this user account. | message: 'Too many requests from this user account.', |
| 128 | Rate limit exceeded | error: 'Rate limit exceeded', |
| 129 | Too many requests from this account, please try again later. | message: 'Too many requests from this account, please try again later.', |
| 155 | API key rate limit exceeded. | message: 'API key rate limit exceeded.', |
| 158 | Rate limit exceeded | error: 'Rate limit exceeded', |
| 159 | API key rate limit exceeded, please try again later. | message: 'API key rate limit exceeded, please try again later.', |

### `src/middleware/rate-limiting/rate-limiter-middleware.ts`
**Found 8 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 31 | Too many requests, please try again later. | message: 'Too many requests, please try again later.', |
| 77 | Redis pipeline failed in rate limiter | message: 'Redis pipeline failed in rate limiter', |
| 96 | Rate limit exceeded | error: 'Rate limit exceeded', |
| 113 | Rate limiter Redis error - failing open | message: 'Rate limiter Redis error - failing open', |
| 138 | Rate limit exceeded. Please slow down. | message: 'Rate limit exceeded. Please slow down.', |
| 151 | User rate limit requires authentication | throw new Error('User rate limit requires authentication'); |
| 195 | Too many requests from this IP address. | message: 'Too many requests from this IP address.', |
| 214 | Too Many Requests | return res.status(429).json({ error: 'Too Many Requests' }); |

### `src/middleware/rate-limiting/websocket-rate-limiter-middleware.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 109 | Rate limit exceeded | throw new Error(reason \|\| 'Rate limit exceeded'); |

## Rooms

### `src/routes/room-api-routes.ts`
**Found 11 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 36 | Room name is required | return res.status(400).json({ error: 'Room name is required' }); |
| 52 | Name taken | if (error instanceof Error && error.message === 'Name taken') { |
| 53 | Name taken | return res.status(400).json({ error: 'Name taken' }); |
| 55 | Create room error | logError('Create room error', error instanceof Error ? error : new Error(String(error))); |
| 88 | Room not found | return res.status(404).json({ error: 'Room not found' }); |
| 97 | Failed to join room | return res.status(400).json({ error: joinResult.error \|\| 'Failed to join room' }); |
| 125 | Room not found | if (error.message === 'Room not found') { |
| 132 | Video service not configured | return res.status(500).json({ error: 'Video service not configured' }); |
| 135 | Join room error | logError('Join room error', error instanceof Error ? error : new Error(String(error))); |
| 154 | Room not found | return res.status(404).json({ error: 'Room not found' }); |
| 159 | Get room error | logError('Get room error', error instanceof Error ? error : new Error(String(error))); |

### `src/services/room-service.ts`
**Found 9 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 20 | Room name is required | throw new Error('Room name is required'); |
| 24 | User ID is required | throw new Error('User ID is required'); |
| 35 | Name taken | throw new Error('Name taken'); |
| 51 | Failed to create room | throw new Error(error.message \|\| 'Failed to create room'); |
| 87 | Room not found | throw new Error('Room not found'); |
| 100 | Room is private and you are not a member | throw new Error('Room is private and you are not a member'); |
| 117 | Failed to join room | throw new Error(joinError.message \|\| 'Failed to join room'); |
| 157 | getRoom error | logError('getRoom error', error instanceof Error ? error : new Error(String(error))); |
| 192 | listRooms error | logError('listRooms error', error instanceof Error ? error : new Error(String(error))); |

## Scheduling

### `src/routes/scheduling-api-routes.ts`
**Found 3 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 15 | Room ID and scheduled time are required | res.status(400).json({ error: 'Room ID and scheduled time are required' }); |
| 24 | Failed to schedule call | res.status(500).json({ error: 'Failed to schedule call' }); |
| 37 | Failed to fetch scheduled calls | res.status(500).json({ error: 'Failed to fetch scheduled calls' }); |

## Search

### `src/routes/search-api-routes.ts`
**Found 7 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 18 | query parameter is required | return res.status(400).json({ error: 'query parameter is required' }); |
| 38 | Search failed | res.status(500).json({ error: 'Search failed', message: error.message }); |
| 51 | query parameter is required | return res.status(400).json({ error: 'query parameter is required' }); |
| 55 | room_id parameter is required | return res.status(400).json({ error: 'room_id parameter is required' }); |
| 66 | Message search failed | res.status(500).json({ error: 'Message search failed', message: error.message }); |
| 79 | query parameter is required | return res.status(400).json({ error: 'query parameter is required' }); |
| 86 | Room search failed | res.status(500).json({ error: 'Room search failed', message: error.message }); |

## Security

### `src/middleware/security/brute-force-protection-middleware.ts`
**Found 5 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 307 | Account temporarily locked | error: 'Account temporarily locked', |
| 322 | CAPTCHA required | error: 'CAPTCHA required', |
| 323 | Please complete the CAPTCHA challenge | message: 'Please complete the CAPTCHA challenge', |
| 335 | Invalid CAPTCHA | error: 'Invalid CAPTCHA', |
| 336 | CAPTCHA verification failed. Please try again. | message: 'CAPTCHA verification failed. Please try again.', |

### `src/services/e2e-encryption.ts`
**Found 8 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 37 | Signal Protocol library not available. Install @signalapp/libsignal-client | throw new Error('Signal Protocol library not available. Install @signalapp/libsignal-client'); |
| 65 | Failed to generate identity key pair | throw new Error('Failed to generate identity key pair'); |
| 127 | Failed to generate prekey bundle | throw new Error('Failed to generate prekey bundle'); |
| 190 | Invalid signed prekey signature | throw new Error('Invalid signed prekey signature'); |
| 222 | Encryption failed | logError('Encryption failed', error instanceof Error ? error : new Error(String(error))); |
| 223 | Failed to encrypt message with Signal Protocol | throw new Error('Failed to encrypt message with Signal Protocol'); |
| 323 | Decryption failed | logError('Decryption failed', error instanceof Error ? error : new Error(String(error))); |
| 324 | Failed to decrypt message with Signal Protocol | throw new Error('Failed to decrypt message with Signal Protocol'); |

### `src/services/encryption-service.ts`
**Found 3 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 87 | Failed to encrypt sensitive data | throw new Error('Failed to encrypt sensitive data'); |
| 111 | Invalid encrypted format | throw new Error('Invalid encrypted format'); |
| 153 | Failed to decrypt sensitive data | throw new Error('Failed to decrypt sensitive data'); |

### `src/services/hardware-accelerated-encryption.ts`
**Found 13 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 61 | Invalid input: data buffer is empty | throw new Error('Invalid input: data buffer is empty'); |
| 65 | Invalid key: key must be at least 16 bytes | throw new Error('Invalid key: key must be at least 16 bytes'); |
| 99 | Unknown encryption error | const errorMessage = error.message \|\| 'Unknown encryption error'; |
| 151 | Software encryption fallback failed: ${error.message} | throw new Error(`Software encryption fallback failed: ${error.message}`); |
| 169 | Invalid input: encrypted buffer is empty | throw new Error('Invalid input: encrypted buffer is empty'); |
| 173 | Invalid key: key must be at least 16 bytes | throw new Error('Invalid key: key must be at least 16 bytes'); |
| 177 | Invalid IV: IV must be at least 16 bytes | throw new Error('Invalid IV: IV must be at least 16 bytes'); |
| 184 | Auth tag required for GCM mode | throw new Error('Auth tag required for GCM mode'); |
| 188 | Invalid auth tag: must be 16 bytes | throw new Error('Invalid auth tag: must be 16 bytes'); |
| 216 | Unknown decryption error | const errorMessage = cbcError.message \|\| 'Unknown decryption error'; |
| 225 | Hardware-accelerated decryption failed: ${errorMessage} | throw new Error(`Hardware-accelerated decryption failed: ${errorMessage}`); |
| 235 | Unknown error | throw new Error(`Hardware-accelerated decryption failed: ${error.message \|\| 'Unknown error'}`); |
| 235 | Hardware-accelerated decryption failed: ${error.message \|\| 'Unknown error'} | throw new Error(`Hardware-accelerated decryption failed: ${error.message \|\| 'Unknown error'}`); |

### `src/services/pii-encryption-integration.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 167 | Migration error: ${error.message} | errors.push(`Migration error: ${error.message}`); |

## Subscriptions

### `src/middleware/subscription-gate-middleware.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 20 | Pro subscription required | error: 'Pro subscription required', |
| 28 | Failed to check subscription | res.status(500).json({ error: 'Failed to check subscription' }); |
| 42 | Team subscription required | error: 'Team subscription required', |
| 50 | Failed to check subscription | res.status(500).json({ error: 'Failed to check subscription' }); |

### `src/routes/entitlements-api-routes.ts`
**Found 2 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 26 | Failed to get entitlements | res.status(500).json({ error: 'Failed to get entitlements' }); |
| 40 | plan and status are required | return res.status(400).json({ error: 'plan and status are required' }); |

### `src/routes/iap-routes.ts`
**Found 2 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 21 | user_id and receipt_data required | return res.status(400).json({ error: 'user_id and receipt_data required' }); |
| 43 | Server error | res.status(500).json({ error: e instanceof Error ? e.message : String(e) \|\| 'Server error' }); |

### `src/routes/subscription-api-routes.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 36 | Failed to get subscription status | res.status(500).json({ error: 'Failed to get subscription status' }); |
| 46 | receiptData required | res.status(400).json({ error: 'receiptData required' }); |
| 54 | Invalid receipt | res.status(400).json({ error: 'Invalid receipt' }); |
| 58 | Failed to verify receipt | res.status(500).json({ error: 'Failed to verify receipt' }); |

### `src/services/apple-iap-service.ts`
**Found 3 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 116 | Parse error: ${error instanceof Error ? error.message : String(error)} | `Parse error: ${error instanceof Error ? error.message : String(error)}` |
| 125 | Apple IAP | logError('Apple IAP', `Request error: ${error.message}`); |
| 125 | Request error: ${error.message} | logError('Apple IAP', `Request error: ${error.message}`); |

## Telemetry

### `src/components/TelemetryExample.tsx`
**Found 8 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 41 | ✅ Enabled | <li>Crash Reports: {userPreferences.crashReports ? '✅ Enabled' : '❌ Disabled'}</li> |
| 41 | ❌ Disabled | <li>Crash Reports: {userPreferences.crashReports ? '✅ Enabled' : '❌ Disabled'}</li> |
| 42 | ✅ Enabled | <li>Usage Analytics: {userPreferences.usageAnalytics ? '✅ Enabled' : '❌ Disabled'}</li> |
| 42 | ❌ Disabled | <li>Usage Analytics: {userPreferences.usageAnalytics ? '✅ Enabled' : '❌ Disabled'}</li> |
| 43 | ✅ Enabled | <li>Performance Metrics: {userPreferences.performanceMetrics ? '✅ Enabled' : '❌ Disabled'}</li> |
| 43 | ❌ Disabled | <li>Performance Metrics: {userPreferences.performanceMetrics ? '✅ Enabled' : '❌ Disabled'}</li> |
| 44 | ✅ Enabled | <li>Feature Usage: {userPreferences.featureUsage ? '✅ Enabled' : '❌ Disabled'}</li> |
| 44 | ❌ Disabled | <li>Feature Usage: {userPreferences.featureUsage ? '✅ Enabled' : '❌ Disabled'}</li> |

### `src/components/TelemetryOptOutFlow.tsx`
**Found 15 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 29 | Crash Reports | title: 'Crash Reports', |
| 30 | Help us fix bugs faster and keep your app running smoothly. | description: 'Help us fix bugs faster and keep your app running smoothly.', |
| 35 | Usage Analytics | title: 'Usage Analytics', |
| 36 | Understand how people use the app to make it better for everyone. | description: 'Understand how people use the app to make it better for everyone.', |
| 41 | Performance Metrics | title: 'Performance Metrics', |
| 42 | Keep the app fast and responsive on all devices. | description: 'Keep the app fast and responsive on all devices.', |
| 47 | Feature Usage | title: 'Feature Usage', |
| 48 | Learn which features you love and which ones need work. | description: 'Learn which features you love and which ones need work.', |
| 114 | icon-shield | <div className="icon-shield">🛡️</div> |
| 120 | promise-icon | <span className="promise-icon">🔒</span> |
| 128 | promise-icon | <span className="promise-icon">❌</span> |
| 136 | promise-icon | <span className="promise-icon">👁️</span> |
| 181 | toggle-slider | <span className="toggle-slider"></span> |
| 215 | s what you | <p className="subtitle">Here's what you've selected:</p> |
| 231 | change-btn | <button className="change-btn">Change →</button> |

### `src/routes/ux-telemetry-api-routes.ts`
**Found 18 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 88 | Invalid batch format | error: 'Invalid batch format', |
| 99 | Batch is empty | error: 'Batch is empty', |
| 106 | Batch too large (max 100 events) | error: 'Batch too large (max 100 events)', |
| 126 | Internal server error | error: 'Internal server error', |
| 145 | Invalid session ID | error: 'Invalid session ID', |
| 154 | Failed to fetch events | error: 'Failed to fetch events', |
| 168 | Internal server error | error: 'Internal server error', |
| 188 | Invalid category | error: 'Invalid category', |
| 198 | Failed to fetch events | error: 'Failed to fetch events', |
| 213 | Internal server error | error: 'Internal server error', |
| 232 | Failed to fetch summary | error: 'Failed to fetch summary', |
| 245 | Internal server error | error: 'Internal server error', |
| 262 | Failed to fetch summary | error: 'Failed to fetch summary', |
| 274 | Internal server error | error: 'Internal server error', |
| 293 | Forbidden: You can only export your own telemetry data | error: 'Forbidden: You can only export your own telemetry data', |
| 302 | Failed to export telemetry | error: 'Failed to export telemetry', |
| 317 | Internal server error | error: 'Internal server error', |
| 352 | Internal server error | error: 'Internal server error', |

### `src/services/ux-telemetry-service.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 59 | Unknown error | const errorMessage = error instanceof Error ? error.message : 'Unknown error'; |

## User Management

### `src/routes/user-data-api-routes.ts`
**Found 7 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 32 | Forbidden: You can only export your own data | error: 'Forbidden: You can only export your own data', |
| 210 | Failed to export user data | error: 'Failed to export user data', |
| 390 | Forbidden: You can only view your own consent records | error: 'Forbidden: You can only view your own consent records', |
| 418 | Failed to get consent records | error: 'Failed to get consent records', |
| 439 | Forbidden: You can only withdraw your own consent | error: 'Forbidden: You can only withdraw your own consent', |
| 447 | Required consent cannot be withdrawn | error: 'Required consent cannot be withdrawn', |
| 503 | Failed to withdraw consent | error: 'Failed to withdraw consent', |

## Validation

### `src/middleware/validation/age-verification-middleware.ts`
**Found 4 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 28 | User not found | return res.status(404).json({ error: 'User not found' }); |
| 33 | Age verification required | error: 'Age verification required', |
| 34 | You must verify that you are 18+ to create or join rooms | message: 'You must verify that you are 18+ to create or join rooms', |
| 44 | Failed to verify age status | res.status(500).json({ error: 'Failed to verify age status' }); |

### `src/middleware/validation/incremental-validation-middleware.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 8 | Validation failed in ${context} | logError(`Validation failed in ${context}`, error instanceof Error ? error : new Error(String(error) |

### `src/middleware/validation/input-validation-middleware.ts`
**Found 5 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 13 | Invalid ${field} format | return res.status(400).json({ error: `Invalid ${field} format` }); |
| 28 | Missing required fields: ${missing.join(', ')} | return res.status(400).json({ error: `Missing required fields: ${missing.join(', ')}` }); |
| 39 | ${field} must be at least ${minLength} characters | return res.status(400).json({ error: `${field} must be at least ${minLength} characters` }); |
| 42 | ${field} must be at most ${maxLength} characters | return res.status(400).json({ error: `${field} must be at most ${maxLength} characters` }); |
| 77 | Invalid input format | res.status(400).json({ error: 'Invalid input format' }); |

### `src/middleware/validation/password-strength-middleware.ts`
**Found 6 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 21 | Password must be at least 8 characters | .min(8, { message: 'Password must be at least 8 characters' }) |
| 22 | Password must be at most 500 characters | .max(500, { message: 'Password must be at most 500 characters' }) |
| 23 | Password must contain at least one uppercase letter | .refine((pwd) => /[A-Z]/.test(pwd), { message: 'Password must contain at least one uppercase letter' |
| 24 | Password must contain at least one lowercase letter | .refine((pwd) => /[a-z]/.test(pwd), { message: 'Password must contain at least one lowercase letter' |
| 25 | Password must contain at least one number | .refine((pwd) => /[0-9]/.test(pwd), { message: 'Password must contain at least one number' }) |
| 28 | Password must contain at least one special character | { message: 'Password must contain at least one special character' } |

## Video/Voice

### `src/routes/agora-api-routes.ts`
**Found 8 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 31 | isMuted must be a boolean | return res.status(400).json({ error: 'isMuted must be a boolean' }); |
| 38 | Room or member not found | return res.status(404).json({ error: 'Room or member not found' }); |
| 43 | Mute toggle error | logError('Mute toggle error', error instanceof Error ? error : new Error(String(error))); |
| 67 | isVideoEnabled must be a boolean | return res.status(400).json({ error: 'isVideoEnabled must be a boolean' }); |
| 74 | Room or member not found, or room is voice-only | return res.status(404).json({ error: 'Room or member not found, or room is voice-only' }); |
| 79 | Video toggle error | logError('Video toggle error', error instanceof Error ? error : new Error(String(error))); |
| 110 | Get members error | logError('Get members error', error instanceof Error ? error : new Error(String(error))); |
| 137 | Leave room error | logError('Leave room error', error instanceof Error ? error : new Error(String(error))); |

### `src/routes/video/join-api-route.ts`
**Found 7 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 49 | Missing required field: roomName | error: 'Missing required field: roomName', |
| 58 | Missing or invalid authorization header | return res.status(401).json({ error: 'Missing or invalid authorization header' }); |
| 91 | User not found | return res.status(404).json({ error: 'User not found' }); |
| 109 | Room not found or access denied | return res.status(404).json({ error: 'Room not found or access denied' }); |
| 118 | Video service not configured | return res.status(500).json({ error: 'Video service not configured' }); |
| 178 | Failed to generate video token | error: 'Failed to generate video token', |
| 200 | LiveKit credentials not found in vault | throw new Error('LiveKit credentials not found in vault'); |

### `src/routes/voice-api-routes.ts`
**Found 11 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 37 | Invalid room_name | return res.status(400).json({ error: 'Invalid room_name' }); |
| 45 | Voice minutes limit reached | error: 'Voice minutes limit reached', |
| 48 | You've reached your monthly voice minutes limit. Upgrade to Pro for unlimited voice calls. | message: `You've reached your monthly voice minutes limit. Upgrade to Pro for unlimited voice calls. |
| 106 | Failed to join voice channel | res.status(500).json({ error: 'Failed to join voice channel' }); |
| 142 | Left voice room | message: 'Left voice room', |
| 146 | Failed to leave voice room | res.status(500).json({ error: 'Failed to leave voice room' }); |
| 160 | Invalid room_name | return res.status(400).json({ error: 'Invalid room_name' }); |
| 166 | Voice room not found | return res.status(404).json({ error: 'Voice room not found' }); |
| 172 | Failed to get voice room info | res.status(500).json({ error: 'Failed to get voice room info' }); |
| 187 | Failed to get voice stats | res.status(500).json({ error: 'Failed to get voice stats' }); |
| 203 | Failed to log voice stats | res.status(500).json({ error: 'Failed to log voice stats' }); |

### `src/services/agora-service.ts`
**Found 5 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 62 | Agora credentials not configured | throw new Error('Agora credentials not configured'); |
| 122 | Failed to get room state | logError('Failed to get room state', error instanceof Error ? error : new Error(String(error))); |
| 153 | Room not found | return { success: false, error: 'Room not found' }; |
| 158 | Room is full | return { success: false, error: 'Room is full' }; |
| 190 | Failed to join room | return { success: false, error: 'Failed to join room' }; |

### `src/services/livekit-service.ts`
**Found 9 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 34 | LiveKit not configured | throw new Error('LiveKit not configured'); |
| 65 | Invalid roomName | throw new Error('Invalid roomName'); |
| 94 | Could not create voice room | throw new Error('Could not create voice room'); |
| 110 | Invalid roomName | throw new Error('Invalid roomName'); |
| 114 | Invalid participantIdentity | throw new Error('Invalid participantIdentity'); |
| 135 | LiveKit API credentials not configured | throw new Error('LiveKit API credentials not configured'); |
| 171 | Invalid roomName | throw new Error('Invalid roomName'); |
| 246 | Invalid roomName | throw new Error('Invalid roomName'); |
| 250 | Invalid participantIdentity | throw new Error('Invalid participantIdentity'); |

### `src/services/livekit-token-service.ts`
**Found 1 user-facing strings**

| Line | String | Context |
|------|--------|----------|
| 31 | Voice access requires Pro subscription. Please upgrade. | throw new Error('Voice access requires Pro subscription. Please upgrade.'); |
