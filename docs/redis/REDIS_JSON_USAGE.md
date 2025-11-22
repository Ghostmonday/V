# Redis JSON Usage Guide

## Current Setup

Your project uses **`ioredis`** (not `redis`/node-redis), so the syntax is slightly different.

## Redis JSON Support

Redis JSON requires:
- ✅ Redis 7.0+ (Railway Redis should support this)
- ✅ Redis JSON module enabled (usually enabled by default)

## Using Redis JSON with ioredis

### Option 1: Use Helper Functions (Recommended)

I've created helper functions in `src/utils/redis-json-helper.ts`:

```typescript
import { redisJsonSet, redisJsonGet } from './utils/redis-json-helper.js';

// Set JSON data
await redisJsonSet('user:1', {
  name: 'Alice',
  emails: ['alice@example.com', 'alice@work.com'],
  address: { city: 'NYC', zip: '10001' }
});

// Get entire object
const user = await redisJsonGet('user:1'); 
// { name: 'Alice', emails: [...], address: {...} }

// Get specific field
const name = await redisJsonGet<string>('user:1', '$.name'); 
// "Alice"

const email = await redisJsonGet<string>('user:1', '$.emails[0]'); 
// "alice@example.com"

const zip = await redisJsonGet<string>('user:1', '$.address.zip'); 
// "10001"
```

### Option 2: Direct ioredis Call

```typescript
import { getRedisClient } from './config/database-config.js';

const redis = getRedisClient();

// Set JSON
await redis.call('JSON.SET', 'user:1', '$', JSON.stringify({
  name: 'Alice',
  emails: ['alice@example.com'],
  address: { city: 'NYC', zip: '10001' }
}));

// Get JSON
const result = await redis.call('JSON.GET', 'user:1', '$') as string;
const user = JSON.parse(result)[0]; // Parse and extract from array
```

## Differences: `redis` vs `ioredis`

| Feature | `redis` (node-redis) | `ioredis` (your project) |
|---------|---------------------|--------------------------|
| Import | `import { createClient } from 'redis'` | `import Redis from 'ioredis'` |
| Connect | `await client.connect()` | Auto-connects |
| JSON Set | `client.json.set()` | `redis.call('JSON.SET', ...)` |
| JSON Get | `client.json.get()` | `redis.call('JSON.GET', ...)` |
| Quit | `await client.quit()` | `await redis.quit()` |

## When to Use Redis JSON

**Good use cases:**
- ✅ Complex nested objects (user profiles, settings)
- ✅ Partial updates (update one field without fetching entire object)
- ✅ JSONPath queries (query nested data)

**Current approach (stringify/parse) is fine for:**
- ✅ Simple objects
- ✅ Full object reads/writes
- ✅ When you don't need partial updates

## Example: User Profile with Redis JSON

```typescript
import { redisJsonSet, redisJsonGet } from './utils/redis-json-helper.js';

// Store user profile
await redisJsonSet('user:alice', {
  name: 'Alice',
  emails: ['alice@example.com', 'alice@work.com'],
  address: { city: 'NYC', zip: '10001' },
  preferences: { theme: 'dark', notifications: true }
});

// Get entire profile
const profile = await redisJsonGet('user:alice');

// Get just the name
const name = await redisJsonGet<string>('user:alice', '$.name');

// Get first email
const email = await redisJsonGet<string>('user:alice', '$.emails[0]');

// Get city
const city = await redisJsonGet<string>('user:alice', '$.address.city');
```

## Check if Redis JSON is Available

```typescript
import { getRedisClient } from './config/database-config.js';

const redis = getRedisClient();

// Check if JSON commands are available
try {
  await redis.call('JSON.SET', 'test:json', '$', JSON.stringify({ test: true }));
  await redis.del('test:json');
  console.log('✅ Redis JSON is available');
} catch (error) {
  console.log('❌ Redis JSON not available:', error);
}
```

## Summary

- ✅ Your project uses `ioredis` (not `redis`)
- ✅ Use `redis.call('JSON.SET', ...)` and `redis.call('JSON.GET', ...)`
- ✅ Helper functions available in `src/utils/redis-json-helper.ts`
- ✅ Railway Redis should support JSON commands



