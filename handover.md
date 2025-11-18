# VibeZ Backend - Handover Documentation

## Overview

VibeZ is a real-time chat and communication platform backend built with TypeScript/Node.js, Express, and WebSockets. The backend provides:

- **Real-time messaging** via WebSocket connections with protobuf-encoded messages
- **HTTP REST API** for room management, user data, moderation, subscriptions, and more
- **Authentication & Authorization** via Supabase JWT tokens with role-based access control
- **Emotional State Tracking** ("Vibes") - tracks and analyzes emotional states in conversations
- **Voice & Video** integration via Agora and LiveKit for real-time communication
- **Moderation & Safety** with automated content filtering, rate limiting, and admin tools
- **Privacy & Security** with end-to-end encryption, GDPR compliance, and zero-knowledge proofs
- **Scalability** with Redis clustering, connection pooling, and horizontal scaling support

The codebase follows a clear, flat structure where file names immediately indicate their purpose. All files use consistent naming patterns: `*-api-routes.ts` for HTTP endpoints, `*-middleware.ts` for Express middleware, `*-service.ts` for business logic, `websocket-*.ts` for WebSocket components, and `*-config.ts` for configuration.

## Architecture Map

### Servers / Entrypoints

- **`src/http-websocket-server.ts`** - Main server entry point. Bootstraps Express HTTP server and WebSocket gateway. Handles CORS, security middleware (Helmet, CSRF), rate limiting, route mounting, Prometheus metrics, and graceful shutdown. Also initializes cron jobs and background workers.

- **`server/socketio-stub-server.ts`** - Legacy Socket.IO stub server (simple implementation, may be deprecated).

### Routes / APIs

All route files follow the `*-api-routes.ts` pattern and are located in `src/routes/`:

- **`message-api-routes.ts`** - REST API for sending, editing, deleting messages
- **`presence-api-routes.ts`** - User presence status (online/offline/idle)
- **`room-api-routes.ts`** - Room creation, joining, configuration
- **`admin-api-routes.ts`** - Admin-only endpoints for system management
- **`admin-moderation-api-routes.ts`** - Admin moderation tools
- **`moderation-api-routes.ts`** - User-facing moderation (flagging, reporting)
- **`voice-api-routes.ts`** - Voice call management
- **`subscription-api-routes.ts`** - Subscription management and billing
- **`entitlements-api-routes.ts`** - Feature entitlements based on subscription tier
- **`health-api-routes.ts`** - Health check endpoints
- **`notify-api-routes.ts`** - Push notification management
- **`reactions-api-routes.ts`** - Message reactions (emojis, etc.)
- **`search-api-routes.ts`** - Message and room search
- **`threads-api-routes.ts`** - Threaded conversations
- **`ux-telemetry-api-routes.ts`** - UX performance telemetry collection
- **`chat-room-config-api-routes.ts`** - Room configuration settings
- **`agora-api-routes.ts`** - Agora video/voice room management
- **`read-receipts-api-routes.ts`** - Read receipt tracking
- **`nicknames-api-routes.ts`** - User nickname management
- **`pinned-api-routes.ts`** - Pinned messages/items
- **`bandwidth-api-routes.ts`** - Bandwidth optimization settings
- **`file-storage-api-routes.ts`** - File upload/download
- **`config-api-routes.ts`** - Client configuration endpoints
- **`telemetry-api-routes.ts`** - System telemetry collection
- **`user-data-api-routes.ts`** - GDPR user data endpoints
- **`privacy-api-routes.ts`** - Privacy and ZKP endpoints
- **`vibes/conversation-api-routes.ts`** - VIBES conversation endpoints
- **`vibes/admin-api-routes.ts`** - VIBES admin endpoints
- **`video/join-api-route.ts`** - Video room joining

### Services

Business logic services in `src/services/` (all follow `*-service.ts` pattern):

**Core Services:**
- **`database-service.ts`** - Database connection and query utilities
- **`message-service.ts`** - Message CRUD operations
- **`message-controller-service.ts`** - Message flow control
- **`message-delivery-service.ts`** - Message delivery tracking
- **`message-archival-service.ts`** - Message archival
- **`message-flagging-service.ts`** - Content flagging
- **`message-queue-service.ts`** - Message queue management
- **`room-service.ts`** - Room management
- **`presence-service.ts`** - Presence tracking
- **`user-authentication-service.ts`** - User authentication
- **`refresh-token-service.ts`** - Token refresh
- **`subscription-service.ts`** - Subscription management
- **`entitlements.ts`** - Feature entitlements

**Communication Services:**
- **`agora-service.ts`** - Agora integration
- **`livekit-service.ts`** - LiveKit integration
- **`livekit-token-service.ts`** - LiveKit token generation
- **`notifications-service.ts`** - Push notifications
- **`webhooks-service.ts`** - Webhook handling

**Moderation & Safety:**
- **`moderation-service.ts`** - Content moderation
- **`perspective-api-service.ts`** - Google Perspective API integration
- **`sentiment-analysis-service.ts`** - Sentiment analysis

**VIBES (Emotional State):**
- **`vibes/conversation-service.ts`** - VIBES conversation management
- **`vibes/sentiment-service.ts`** - Sentiment analysis for VIBES
- **`vibes/analytics-service.ts`** - VIBES analytics
- **`vibes/error-handler.ts`** - VIBES error handling
- **`vibes/query-helpers.ts`** - VIBES query utilities
- **`vibes/validation.ts`** - VIBES validation
- **`vibes/constants.ts`** - VIBES constants

**Privacy & Security:**
- **`encryption-service.ts`** - Encryption utilities
- **`e2e-encryption.ts`** - End-to-end encryption
- **`hardware-accelerated-encryption.ts`** - Hardware-accelerated encryption
- **`pii-encryption-integration.ts`** - PII encryption
- **`zkp-service.ts`** - Zero-knowledge proofs
- **`data-deletion-service.ts`** - GDPR data deletion

**Infrastructure:**
- **`cache-service.ts`** - Caching layer
- **`monitoring-service.ts`** - System monitoring
- **`telemetry-service.ts`** - Telemetry collection
- **`ux-telemetry-service.ts`** - UX telemetry
- **`ux-telemetry-redaction.ts`** - UX telemetry redaction
- **`opentelemetry-integration.ts`** - OpenTelemetry integration
- **`sharding-service.ts`** - Database sharding
- **`partition-management-service.ts`** - Partition management
- **`partition-monitoring-service.ts`** - Partition monitoring
- **`query-optimization-service.ts`** - Query optimization
- **`slow-query-tracker.ts`** - Slow query tracking
- **`connection-pool-monitor.ts`** - Connection pool monitoring

**Other Services:**
- **`file-storage-service.ts`** - File storage
- **`pfs-media-service.ts`** - PFS media handling
- **`search-service.ts`** - Search functionality
- **`nickname-service.ts`** - Nickname management
- **`pinned-items-service.ts`** - Pinned items
- **`read-receipts-service.ts`** - Read receipts
- **`poll-service.ts`** - Polls
- **`bot-invite-service.ts`** - Bot invitations
- **`api-keys-service.ts`** - API key management
- **`config-service.ts`** - Configuration management
- **`usage-service.ts`** - Usage tracking
- **`usage-meter-service.ts`** - Usage metering
- **`bandwidth-service.ts`** - Bandwidth management
- **`apple-iap-service.ts`** - Apple In-App Purchase
- **`apple-jwks-verifier.ts`** - Apple JWKS verification
- **`compression-service.ts`** - Compression utilities

### Middleware

Express middleware in `src/middleware/` (all follow `*-middleware.ts` pattern):

**Authentication & Authorization:**
- **`supabase-auth-middleware.ts`** - Supabase JWT authentication
- **`vibes-auth-middleware.ts`** - VIBES authentication
- **`admin-auth-middleware.ts`** - Admin authentication
- **`age-verification-middleware.ts`** - Age verification (18+)

**Security:**
- **`rate-limiter-middleware.ts`** - Custom token bucket rate limiting
- **`express-rate-limit-middleware.ts`** - Express rate limiting wrapper
- **`websocket-rate-limiter-middleware.ts`** - WebSocket rate limiting
- **`websocket-message-rate-limiter-middleware.ts`** - WebSocket message rate limiting
- **`brute-force-protection-middleware.ts`** - Brute force protection
- **`password-strength-middleware.ts`** - Password strength validation
- **`input-validation-middleware.ts`** - Input validation and sanitization
- **`file-upload-security-middleware.ts`** - File upload security
- **`circuit-breaker-middleware.ts`** - Circuit breaker pattern

**Moderation:**
- **`moderation-middleware.ts`** - Content moderation
- **`incremental-validation-middleware.ts`** - Incremental validation

**Infrastructure:**
- **`error-middleware.ts`** - Error handling
- **`error-alerting-middleware.ts`** - Error alerting
- **`structured-logging-middleware.ts`** - Structured logging
- **`telemetry-middleware.ts`** - Telemetry collection
- **`cache-middleware.ts`** - Caching
- **`database-transaction-middleware.ts`** - Database transactions
- **`subscription-gate-middleware.ts`** - Subscription gating

### WebSocket Gateway & Handlers

WebSocket components in `src/ws/`:

- **`websocket-gateway.ts`** - Main WebSocket gateway. Handles connections, protobuf message decoding, routing to handlers, connection management, and Redis pub/sub integration.

- **`websocket-connection-manager.ts`** - Manages WebSocket connections, room subscriptions, reconnection logic, backoff delays, and connection state tracking.

- **`websocket-utils.ts`** - WebSocket utilities for room registration, Redis pub/sub setup, and broadcasting.

**Handlers** (in `src/ws/handlers/`):
- **`websocket-messaging-handler.ts`** - Handles real-time message sending/receiving
- **`websocket-presence-handler.ts`** - Handles presence updates (online/offline/idle)
- **`websocket-read-receipts-handler.ts`** - Handles read receipt updates
- **`websocket-delivery-ack-handler.ts`** - Handles delivery acknowledgments
- **`websocket-reactions-threads-handler.ts`** - Handles reactions and threaded messages

### Database / Config

Configuration files in `src/config/`:

- **`database-config.ts`** - Database connection configuration (Supabase/PostgreSQL)
- **`redis-cluster-config.ts`** - Redis cluster configuration
- **`redis-failover-config.ts`** - Redis failover configuration
- **`redis-pubsub-config.ts`** - Redis pub/sub configuration
- **`redis-streams-config.ts`** - Redis streams configuration
- **`encryption-config.ts`** - Encryption configuration
- **`llm-params-config.ts`** - LLM parameters configuration
- **`vibes-config.ts`** - VIBES configuration

**Server Configuration:**
- **`src/server-config.ts`** - Server configuration (port, rate limits, CORS, etc.)

### Jobs / Workers

Background jobs in `src/jobs/`:
- **`data-retention-cron-job.ts`** - Data retention cleanup job
- **`expire-temporary-rooms-cron-job.ts`** - Temporary room expiration job
- **`partition-management-cron-job.ts`** - Database partition management job

Workers in `src/workers/`:
- **`sin-ai-worker.ts`** - Sin AI worker for AI-powered features

### Shared Utilities

Shared utilities in `src/shared/`:
- **`logger-shared.ts`** - Shared logging utilities
- **`supabase-client-shared.ts`** - Shared Supabase client
- **`supabase-helpers-shared.ts`** - Shared Supabase helper functions

### Utils

Utility functions in `src/utils/`:
- **`circuit-breaker-utils.ts`** - Circuit breaker utilities
- **`input-sanitizer-utils.ts`** - Input sanitization utilities
- **`prompt-sanitizer-utils.ts`** - Prompt sanitization utilities

### Types

Type definitions in `src/types/`:
- **`auth-types.ts`** - Authentication types
- **`message-types.ts`** - Message types
- **`vibes-types.ts`** - VIBES types
- **`ux-telemetry-types.ts`** - UX telemetry types
- **`generated-types.ts`** - Generated types
- **`livekit-types.d.ts`** - LiveKit types
- **`compression-types.d.ts`** - Compression types

### Telemetry

Telemetry exports in `src/telemetry/`:
- **`telemetry-exports.ts`** - Telemetry function exports

### Tests

Test files in `src/tests/` and `src/**/__tests__/`:
- Integration tests for WebSocket, Redis, API endpoints
- Unit tests for services and middleware
- All test files follow `*.test.ts` pattern

## File Reference (Flat Inventory)

### Entry Points
- `src/http-websocket-server.ts` - Main HTTP + WebSocket server entry point

### Routes (src/routes/)
- `message-api-routes.ts` - REST API for messages
- `presence-api-routes.ts` - REST API for presence
- `room-api-routes.ts` - REST API for rooms
- `admin-api-routes.ts` - REST API for admin operations
- `admin-moderation-api-routes.ts` - REST API for admin moderation
- `moderation-api-routes.ts` - REST API for user moderation
- `voice-api-routes.ts` - REST API for voice calls
- `subscription-api-routes.ts` - REST API for subscriptions
- `entitlements-api-routes.ts` - REST API for entitlements
- `health-api-routes.ts` - REST API for health checks
- `notify-api-routes.ts` - REST API for notifications
- `reactions-api-routes.ts` - REST API for reactions
- `search-api-routes.ts` - REST API for search
- `threads-api-routes.ts` - REST API for threads
- `ux-telemetry-api-routes.ts` - REST API for UX telemetry
- `chat-room-config-api-routes.ts` - REST API for room config
- `agora-api-routes.ts` - REST API for Agora rooms
- `read-receipts-api-routes.ts` - REST API for read receipts
- `nicknames-api-routes.ts` - REST API for nicknames
- `pinned-api-routes.ts` - REST API for pinned items
- `bandwidth-api-routes.ts` - REST API for bandwidth settings
- `file-storage-api-routes.ts` - REST API for file storage
- `config-api-routes.ts` - REST API for configuration
- `telemetry-api-routes.ts` - REST API for telemetry
- `user-data-api-routes.ts` - REST API for user data (GDPR)
- `privacy-api-routes.ts` - REST API for privacy features
- `vibes/conversation-api-routes.ts` - REST API for VIBES conversations
- `vibes/admin-api-routes.ts` - REST API for VIBES admin
- `video/join-api-route.ts` - REST API for video room joining

### Services (src/services/)
- `database-service.ts` - Database connection and utilities
- `message-service.ts` - Message CRUD operations
- `message-controller-service.ts` - Message flow control
- `message-delivery-service.ts` - Message delivery tracking
- `message-archival-service.ts` - Message archival
- `message-flagging-service.ts` - Content flagging
- `message-queue-service.ts` - Message queue management
- `room-service.ts` - Room management
- `presence-service.ts` - Presence tracking
- `user-authentication-service.ts` - User authentication
- `refresh-token-service.ts` - Token refresh
- `subscription-service.ts` - Subscription management
- `entitlements.ts` - Feature entitlements
- `agora-service.ts` - Agora integration
- `livekit-service.ts` - LiveKit integration
- `livekit-token-service.ts` - LiveKit token generation
- `notifications-service.ts` - Push notifications
- `webhooks-service.ts` - Webhook handling
- `moderation-service.ts` - Content moderation
- `perspective-api-service.ts` - Google Perspective API
- `sentiment-analysis-service.ts` - Sentiment analysis
- `vibes/conversation-service.ts` - VIBES conversation management
- `vibes/sentiment-service.ts` - VIBES sentiment analysis
- `vibes/analytics-service.ts` - VIBES analytics
- `encryption-service.ts` - Encryption utilities
- `e2e-encryption.ts` - End-to-end encryption
- `hardware-accelerated-encryption.ts` - Hardware-accelerated encryption
- `pii-encryption-integration.ts` - PII encryption
- `zkp-service.ts` - Zero-knowledge proofs
- `data-deletion-service.ts` - GDPR data deletion
- `cache-service.ts` - Caching layer
- `monitoring-service.ts` - System monitoring
- `telemetry-service.ts` - Telemetry collection
- `ux-telemetry-service.ts` - UX telemetry
- `ux-telemetry-redaction.ts` - UX telemetry redaction
- `opentelemetry-integration.ts` - OpenTelemetry integration
- `sharding-service.ts` - Database sharding
- `partition-management-service.ts` - Partition management
- `partition-monitoring-service.ts` - Partition monitoring
- `query-optimization-service.ts` - Query optimization
- `slow-query-tracker.ts` - Slow query tracking
- `connection-pool-monitor.ts` - Connection pool monitoring
- `file-storage-service.ts` - File storage
- `pfs-media-service.ts` - PFS media handling
- `search-service.ts` - Search functionality
- `nickname-service.ts` - Nickname management
- `pinned-items-service.ts` - Pinned items
- `read-receipts-service.ts` - Read receipts
- `poll-service.ts` - Polls
- `bot-invite-service.ts` - Bot invitations
- `api-keys-service.ts` - API key management
- `config-service.ts` - Configuration management
- `usage-service.ts` - Usage tracking
- `usage-meter-service.ts` - Usage metering
- `bandwidth-service.ts` - Bandwidth management
- `apple-iap-service.ts` - Apple In-App Purchase
- `apple-jwks-verifier.ts` - Apple JWKS verification
- `compression-service.ts` - Compression utilities

### Middleware (src/middleware/)
- `supabase-auth-middleware.ts` - Supabase JWT authentication
- `vibes-auth-middleware.ts` - VIBES authentication
- `admin-auth-middleware.ts` - Admin authentication
- `age-verification-middleware.ts` - Age verification
- `rate-limiter-middleware.ts` - Custom rate limiting
- `express-rate-limit-middleware.ts` - Express rate limiting
- `websocket-rate-limiter-middleware.ts` - WebSocket rate limiting
- `websocket-message-rate-limiter-middleware.ts` - WebSocket message rate limiting
- `brute-force-protection-middleware.ts` - Brute force protection
- `password-strength-middleware.ts` - Password strength validation
- `input-validation-middleware.ts` - Input validation
- `file-upload-security-middleware.ts` - File upload security
- `circuit-breaker-middleware.ts` - Circuit breaker
- `moderation-middleware.ts` - Content moderation
- `incremental-validation-middleware.ts` - Incremental validation
- `error-middleware.ts` - Error handling
- `error-alerting-middleware.ts` - Error alerting
- `structured-logging-middleware.ts` - Structured logging
- `telemetry-middleware.ts` - Telemetry collection
- `cache-middleware.ts` - Caching
- `database-transaction-middleware.ts` - Database transactions
- `subscription-gate-middleware.ts` - Subscription gating

### WebSocket (src/ws/)
- `websocket-gateway.ts` - WebSocket gateway (main entry)
- `websocket-connection-manager.ts` - Connection management
- `websocket-utils.ts` - WebSocket utilities
- `handlers/websocket-messaging-handler.ts` - Message handler
- `handlers/websocket-presence-handler.ts` - Presence handler
- `handlers/websocket-read-receipts-handler.ts` - Read receipts handler
- `handlers/websocket-delivery-ack-handler.ts` - Delivery ack handler
- `handlers/websocket-reactions-threads-handler.ts` - Reactions/threads handler

### Config (src/config/)
- `database-config.ts` - Database configuration
- `redis-cluster-config.ts` - Redis cluster config
- `redis-failover-config.ts` - Redis failover config
- `redis-pubsub-config.ts` - Redis pub/sub config
- `redis-streams-config.ts` - Redis streams config
- `encryption-config.ts` - Encryption config
- `llm-params-config.ts` - LLM params config
- `vibes-config.ts` - VIBES config

### Jobs (src/jobs/)
- `data-retention-cron-job.ts` - Data retention job
- `expire-temporary-rooms-cron-job.ts` - Room expiration job
- `partition-management-cron-job.ts` - Partition management job

### Workers (src/workers/)
- `sin-ai-worker.ts` - Sin AI worker

### Shared (src/shared/)
- `logger-shared.ts` - Shared logger
- `supabase-client-shared.ts` - Shared Supabase client
- `supabase-helpers-shared.ts` - Shared Supabase helpers

### Utils (src/utils/)
- `circuit-breaker-utils.ts` - Circuit breaker utils
- `input-sanitizer-utils.ts` - Input sanitizer utils
- `prompt-sanitizer-utils.ts` - Prompt sanitizer utils

### Types (src/types/)
- `auth-types.ts` - Authentication types
- `message-types.ts` - Message types
- `vibes-types.ts` - VIBES types
- `ux-telemetry-types.ts` - UX telemetry types
- `generated-types.ts` - Generated types
- `livekit-types.d.ts` - LiveKit types
- `compression-types.d.ts` - Compression types

### Telemetry (src/telemetry/)
- `telemetry-exports.ts` - Telemetry exports

## UI Mockups

### Web UI Mockup

```
┌─────────────────────────────────────────────────────────────────┐
│ VibeZ - Real-time Chat                                           │
├──────────────┬──────────────────────────────────────────────────┤
│              │                                                   │
│ CONVERSATIONS│  ACTIVE CONVERSATION                             │
│              │                                                   │
│ ┌──────────┐ │  ┌──────────────────────────────────────────┐   │
│ │ Room 1   │ │  │ Room: General Discussion                  │   │
│ │ 🟢 12    │ │  │ [Online: 12] [Typing: 3]                  │   │
│ └──────────┘ │  └──────────────────────────────────────────┘   │
│              │                                                   │
│ ┌──────────┐ │  ┌──────────────────────────────────────────┐   │
│ │ Room 2   │ │  │ Alice: Hey everyone! 😊                   │   │
│ │ 🟡 5     │ │  │ [Vibe: 😊 Happy] [Sent: 2m ago]           │   │
│ └──────────┘ │  └──────────────────────────────────────────┘   │
│              │                                                   │
│ ┌──────────┐ │  ┌──────────────────────────────────────────┐   │
│ │ Room 3   │ │  │ Bob: Working on the new feature           │   │
│ │ ⚪ 0     │ │  │ [Vibe: 😐 Neutral] [Sent: 5m ago]         │   │
│ └──────────┘ │  └──────────────────────────────────────────┘   │
│              │                                                   │
│ ┌──────────┐ │  ┌──────────────────────────────────────────┐   │
│ │ Room 4   │ │  │ Charlie: Can someone help? 🤔             │   │
│ │ 🟢 8     │ │  │ [Vibe: 🤔 Curious] [Sent: 1m ago]         │   │
│ └──────────┘ │  └──────────────────────────────────────────┘   │
│              │                                                   │
│              │  ┌──────────────────────────────────────────┐   │
│              │  │ [Type your message...] [😊] [📎] [Send]   │   │
│              │  └──────────────────────────────────────────┘   │
│              │                                                   │
│              │  Real-time Status: 🟢 Connected                 │
│              │  Presence: 12 online, 3 typing                  │
└──────────────┴──────────────────────────────────────────────────┘
```

**Key Features:**
- Left sidebar: List of conversations/rooms with online count and status indicators
- Main panel: Active conversation with messages showing:
  - Message content
  - Vibe/emotional state indicator (😊 Happy, 😐 Neutral, 🤔 Curious, etc.)
  - Timestamp
  - Read receipts
- Real-time indicators: Connection status, online count, typing indicators
- Input area: Message composer with vibe selector, file attachment, send button

### iOS UI Mockup (Portrait)

```
┌─────────────────────────────────┐
│  VibeZ                    [🔔]   │ ← Header/Title Bar
├─────────────────────────────────┤
│                                 │
│  CONVERSATIONS                  │
│                                 │
│  ┌───────────────────────────┐ │
│  │ Room 1              🟢 12 │ │ ← Room list item
│  │ Last: Hey! [😊]     2m ago │ │   with vibe indicator
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ Room 2              🟡 5  │ │
│  │ Last: Working... [😐] 5m  │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ Room 3              ⚪ 0  │ │
│  │ Last: Can help? [🤔] 1m   │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ Room 4              🟢 8  │ │
│  │ Last: Thanks! [😊]  10m  │ │
│  └───────────────────────────┘ │
│                                 │
│                                 │
│                                 │
├─────────────────────────────────┤
│ [🏠] [💬] [😊] [👤]            │ ← Bottom Navigation
│ Home Rooms Vibes Profile        │
└─────────────────────────────────┘
```

**When viewing a conversation:**

```
┌─────────────────────────────────┐
│  ← Room 1                [⚙️]   │ ← Back button + Room name
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐ │
│  │ Alice: Hey everyone! 😊   │ │ ← Message bubble
│  │ [Vibe: 😊 Happy]          │ │   with vibe indicator
│  │ [Sent: 2m ago] [✓✓]       │ │   and read receipts
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ Bob: Working on feature    │ │
│  │ [Vibe: 😐 Neutral]         │ │
│  │ [Sent: 5m ago] [✓]         │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ Charlie: Can help? 🤔     │ │
│  │ [Vibe: 🤔 Curious]        │ │
│  │ [Sent: 1m ago] [✓✓]       │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ [Type message...] [😊] [📎]│ │ ← Message input
│  └───────────────────────────┘ │   with vibe selector
│                                 │
│  🟢 Connected | 12 online       │ ← Status bar
├─────────────────────────────────┤
│ [🏠] [💬] [😊] [👤]            │ ← Bottom Navigation
│ Home Rooms Vibes Profile        │
└─────────────────────────────────┘
```

**Key Features:**
- Top: Header with room name and settings
- Middle: Message thread with:
  - Message bubbles
  - Vibe/emotional state indicators below each message
  - Timestamps
  - Read receipts (✓ = sent, ✓✓ = read)
- Bottom: Message input with vibe selector (😊) and attachment button (📎)
- Status bar: Connection status and online count
- Bottom nav: Home, Rooms, Vibes (emotional state dashboard), Profile

**Vibes Tab (Emotional State Dashboard):**

```
┌─────────────────────────────────┐
│  Vibes Dashboard          [⚙️]  │
├─────────────────────────────────┤
│                                 │
│  Your Emotional State           │
│  ┌───────────────────────────┐ │
│  │ Current: 😊 Happy          │ │
│  │ Trend: ↗️ Improving        │ │
│  └───────────────────────────┘ │
│                                 │
│  Room Vibes                     │
│  ┌───────────────────────────┐ │
│  │ Room 1: 😊 Happy (80%)    │ │
│  │ Room 2: 😐 Neutral (60%)  │ │
│  │ Room 3: 🤔 Curious (45%)  │ │
│  └───────────────────────────┘ │
│                                 │
│  Recent Activity                │
│  ┌───────────────────────────┐ │
│  │ 😊 Happy moments: 12      │ │
│  │ 😐 Neutral: 8            │ │
│  │ 🤔 Questions: 5          │ │
│  └───────────────────────────┘ │
│                                 │
├─────────────────────────────────┤
│ [🏠] [💬] [😊] [👤]            │
│ Home Rooms Vibes Profile        │
└─────────────────────────────────┘
```

## Summary

This refactoring renamed **~150+ files** to follow clear, consistent naming patterns:

- **Main entry point**: `src/server/index.ts` → `src/http-websocket-server.ts`
- **Routes**: All renamed to `*-api-routes.ts` pattern (25+ files)
- **Middleware**: All renamed to `*-middleware.ts` pattern (20+ files)
- **Services**: Fixed casing and ensured `*-service.ts` pattern (60+ files)
- **Config**: All renamed for clarity (8 files)
- **WebSocket**: All prefixed with `websocket-` (5+ files)
- **Jobs/Workers/Shared/Utils/Types**: All renamed for clarity (15+ files)

**Major structural changes:**
- Flattened `src/server/` directory (moved `server/index.ts` to root, `server/utils/config.ts` to `server-config.ts`)
- All imports updated across the codebase
- Consistent naming patterns throughout

**TODOs for future cleanup:**
1. Consider consolidating `rate-limiter-middleware.ts` and `express-rate-limit-middleware.ts` if both aren't needed
2. Review `server/socketio-stub-server.ts` - may be deprecated
3. Consider splitting large service files if they grow too complex
4. Add JSDoc comments to all exported functions for better IDE support
5. Consider creating index files for common imports (e.g., `middleware/index.ts`)

