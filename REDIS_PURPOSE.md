# What Redis is Used For in Your Project

## Overview
Redis is a **critical component** of your application. It's used for **real-time features**, **caching**, **rate limiting**, and **cross-process communication**.

---

## 🎯 Main Uses of Redis

### 1. **Real-Time Presence & WebSocket Communication** ⚡
- **User presence**: Track who's online/offline in real-time
- **Room presence**: Track who's in which chat room
- **WebSocket broadcasting**: Send messages to multiple users across different server instances
- **Cross-process messaging**: When you have multiple server instances, Redis helps them communicate

**Files:**
- `src/services/presence-service.ts` - User online/offline status
- `src/ws/websocket-utils.ts` - Broadcasting messages to rooms
- `src/ws/websocket-gateway.ts` - WebSocket connection management

### 2. **Rate Limiting** 🚦
- **API rate limiting**: Prevent abuse by limiting requests per user/IP
- **WebSocket message rate limiting**: Limit how many messages users can send
- **Sliding window algorithm**: Uses Redis sorted sets for accurate rate limiting

**Files:**
- `src/middleware/rate-limiting/rate-limiter-middleware.ts` - API rate limits
- `src/middleware/rate-limiting/websocket-message-rate-limiter-middleware.ts` - WebSocket limits

### 3. **Caching** 💾
- **Frequently accessed data**: Cache database queries to reduce load
- **TTL-based expiration**: Automatically expire cached data
- **Performance optimization**: Faster response times for cached data

**Files:**
- `src/services/cache-service.ts` - General caching layer

### 4. **Message Queue & Delivery** 📬
- **Message queuing**: Queue messages for delivery
- **Retry logic**: Store failed message deliveries for retry
- **Background processing**: Process messages asynchronously

**Files:**
- `src/services/message-queue-service.ts` - Message queuing

### 5. **LiveKit/Voice Session Management** 🎤
- **Participant tracking**: Cache LiveKit room participants
- **Session metadata**: Store voice/video call session data
- **Presence sync**: Sync participant presence between LiveKit and your app

**Files:**
- `src/services/livekit-service.ts` - Voice/video session management

### 6. **PFS (Perfect Forward Secrecy) Media Encryption** 🔐
- **Ephemeral keys**: Store temporary encryption keys for secure media calls
- **Session management**: Manage encryption sessions for PFS calls
- **Key expiration**: Auto-expire keys after call ends (2 hour TTL)

**Files:**
- `src/services/pfs-media-service.ts` - Secure media encryption

### 7. **Read Receipts** ✅
- **Message read status**: Track which messages have been read
- **User read tracking**: Track what each user has read

**Files:**
- `src/services/read-receipts-service.ts` - Read receipt tracking

### 8. **Search & Polling** 🔍
- **Search result caching**: Cache search results
- **Poll data**: Store poll votes and results

**Files:**
- `src/services/search-service.ts` - Search functionality
- `src/services/poll-service.ts` - Poll management

---

## ⚠️ Why Redis is Required

**Without Redis, these features won't work:**
- ❌ Real-time presence (users won't see who's online)
- ❌ WebSocket broadcasting (messages won't reach all users)
- ❌ Rate limiting (API abuse protection disabled)
- ❌ Caching (slower performance)
- ❌ Cross-process communication (multi-instance deployments fail)

**The server will crash on startup** if Redis isn't available because:
- Redis client initialization happens during server startup
- Many features depend on Redis being available
- The code throws an error if REDIS_URL is missing/invalid

---

## 🏗️ Architecture

```
Your App (Multiple Instances)
    ↓
Redis (Single Source of Truth)
    ↓
- Presence data
- Rate limit counters
- Cache
- Message queues
- WebSocket pub/sub
```

**Why this matters:**
- If you scale to multiple server instances, Redis ensures they all share the same state
- Real-time features work across all instances
- Rate limiting works globally (not per-instance)

---

## 📊 Summary

| Use Case | Importance | Impact if Missing |
|----------|-----------|-------------------|
| Real-time presence | 🔴 Critical | Users can't see who's online |
| WebSocket broadcasting | 🔴 Critical | Messages don't reach all users |
| Rate limiting | 🟡 Important | API vulnerable to abuse |
| Caching | 🟡 Important | Slower performance |
| Message queuing | 🟡 Important | Message delivery issues |
| PFS encryption | 🟢 Nice to have | Secure calls won't work |

---

## ✅ Conclusion

**Redis is essential** for your real-time chat/communication app. It enables:
- Real-time features (presence, WebSocket)
- Performance (caching)
- Security (rate limiting)
- Scalability (cross-process communication)

**That's why the server crashes if REDIS_URL is missing** - Redis is a core dependency, not optional.

