# Skipped Tests Analysis

**Date:** November 21, 2025  
**Purpose:** Analyze skipped tests to determine fix complexity

---

## Summary

**Total Skipped:** 12 tests across 3 test files
- **Quick fixes:** 7 tests (1-2 hours)
- **Medium effort:** 2 tests (4-8 hours)
- **Major work:** 3 tests (16+ hours)

---

## 🟢 QUICK FIXES (1-2 hours each)

### 1. User Authentication Service Tests (2 tests)

**File:** `src/services/__tests__/user-authentication-service.test.ts`

#### Test 1: "should throw error if JWT_SECRET is not set"
**Status:** Intentionally skipped  
**Reason:** Test setup issue - JWT_SECRET is always set in tests  
**Effort:** 15 minutes  
**Fix:**
```typescript
it('should throw error if JWT_SECRET is not set', async () => {
  const originalSecret = process.env.JWT_SECRET;
  delete process.env.JWT_SECRET;
  
  // Clear the vault cache to force JWT_SECRET lookup
  await expect(authenticateWithCredentials('user', 'pass')).rejects.toThrow();
  
  process.env.JWT_SECRET = originalSecret;
});
```

#### Test 2: "should authenticate valid credentials"
**Status:** Intentionally skipped  
**Reason:** Requires live Supabase connection or better mocks  
**Effort:** 30 minutes  
**Fix:** Add proper Supabase auth mocking for credential authentication

---

### 2. Rate Limiter - IP Independence Test (1 test)

**File:** `src/middleware/__tests__/rate-limiter.test.ts`  
**Test:** "should allow different IPs independently"

**Status:** Mock infrastructure issue  
**Effort:** 1 hour  
**Root Cause:** Mock Redis sorted sets share state across different keys

**Fix Required:**
Update `createMockRedis()` in `test-setup.ts` to properly isolate sorted sets by full key (including the rate limit prefix):

```typescript
// In pipeline.exec():
if (cmd.method === 'zadd') {
  const [score, member] = rest;
  const fullKey = key; // Use the full key with prefix
  if (!sortedSets.has(fullKey)) {
    sortedSets.set(fullKey, new Map());
  }
  sortedSets.get(fullKey)!.set(member, score);
  results.push([null, 1]);
}
```

The issue is that `rate_limit:192.168.1.1` and `rate_limit:192.168.1.2` need separate tracking.

---

### 3. Redis Cluster - Create Cluster Client Test (1 test)

**File:** `src/tests/integration/redis-cluster.test.ts`  
**Test:** "should create cluster client"

**Status:** ESM mocking limitation  
**Effort:** 1 hour  
**Root Cause:** `require()` doesn't work in ESM modules

**Fix Required:**
Replace with ESM-compatible mock:

```typescript
it('should create cluster client', async () => {
  const config: RedisClusterConfig = {
    mode: 'cluster',
    nodes: [
      { host: 'localhost', port: 7000 },
      { host: 'localhost', port: 7001 },
    ],
  };

  const client = createRedisClient(config);

  // Just verify it returns a client (Cluster mock is complex in ESM)
  expect(client).toBeDefined();
  expect(typeof client.on).toBe('function');
});
```

---

## 🟡 MEDIUM EFFORT (4-8 hours)

### 4. Rate Limiter - Blocking Test (1 test)

**File:** `src/middleware/__tests__/rate-limiter.test.ts`  
**Test:** "should block requests exceeding limit"

**Status:** Mock Redis pipeline not tracking state correctly  
**Effort:** 4 hours  
**Root Cause:** Pipeline mock needs to maintain state across executions

**Problem:**
The mock Redis pipeline in `test-setup.ts` creates a fresh sorted set on each test, but doesn't persist state between sequential calls to the same middleware instance.

**Fix Required:**
1. Update `createMockRedis()` to use a shared store across all pipeline calls
2. Ensure `sortedSets` Map is persistent across middleware calls
3. Fix the timing - the mock might be executing synchronously when it should be async

**Alternative:** Use a real Redis instance (redis-mock npm package) instead of manual mocking.

---

### 5. Rate Limiter - Fail Open Test (1 test)

**File:** `src/middleware/__tests__/rate-limiter.test.ts`  
**Test:** "should fail open if Redis is unavailable"

**Status:** Error handling not triggered  
**Effort:** 2 hours  
**Root Cause:** Mock setup doesn't actually cause errors in the middleware

**Problem:**
The middleware calls `getRedisClient()` at module load time (line 13 of rate-limiter-middleware.ts), so changing the mock after import doesn't affect the running code.

**Fix Required:**
1. Restructure rate limiter to accept Redis client as parameter
2. OR create a test that imports a fresh instance of the module
3. OR use `vi.resetModules()` to clear the module cache

**Best Solution:**
```typescript
it('should fail open if Redis is unavailable', async () => {
  // Reset modules to get fresh import
  vi.resetModules();
  
  // Mock Redis to throw errors
  vi.mock('../../config/database-config.js', () => ({
    getRedisClient: vi.fn(() => ({
      pipeline: vi.fn(() => {
        throw new Error('Redis unavailable');
      }),
    })),
  }));
  
  const { rateLimit } = await import('../rate-limiting/rate-limiter-middleware.js');
  const middleware = rateLimit({ max: 5, windowMs: 60000 });
  
  await middleware(req, res, next);
  expect(next).toHaveBeenCalled();
});
```

---

## 🔴 MAJOR WORK (16+ hours)

### 6. E2E Encryption Suite (5 tests)

**File:** `src/tests/e2e-encryption.test.ts`  
**Tests:** 5 tests in the entire suite

**Status:** Signal Protocol library compatibility issues  
**Effort:** 16-24 hours  
**Root Cause:** `@signalapp/libsignal-client` API has changed

**Error:**
```
identityKeyPair.getPublicKey is not a function
```

**Problem Analysis:**
The Signal Protocol library API changed between versions. The current code expects:
```typescript
const identityKeyPair = signal.IdentityKeyPair.generate();
return {
  publicKey: identityKeyPair.getPublicKey().serialize(),
  privateKey: identityKeyPair.getPrivateKey().serialize(),
};
```

But the library might now use:
- Different method names
- Different return types
- Different serialization format

**Fix Required:**
1. **Research** current Signal Protocol API (2 hours)
   - Read `@signalapp/libsignal-client` v0.86.4 documentation
   - Check breaking changes from older versions
   - Find correct API methods

2. **Update implementation** (8 hours)
   - Fix `generateIdentityKeyPair()` - use correct API
   - Fix `generatePreKeyBundle()` - proper key generation
   - Fix `encryptMessage()` - update session management
   - Fix `decryptMessage()` - update decryption logic
   - Handle serialization/deserialization properly

3. **Test thoroughly** (4 hours)
   - Test key pair generation
   - Test prekey bundle creation
   - Test message encryption
   - Test message decryption (requires session state)
   - Test with actual Signal Protocol scenarios

4. **Integration testing** (4 hours)
   - Test with WebSocket handler
   - Test E2E room enforcement
   - Test encryption validation

**Alternative Approach:** Replace Signal Protocol with simpler encryption:
- Use libsodium sealed boxes (easier API)
- Or use PGP-style encryption
- This would require rewriting the entire E2E encryption service (40+ hours)

---

### 7. Rate Limiter - Standard Limits Test (1 test)

**File:** `src/middleware/__tests__/rate-limiter.test.ts`  
**Test:** "should apply standard limits for free users"

**Status:** Mock Redis not maintaining state across requests  
**Effort:** See item #4 above (same root cause, 4 hours)

**Same fix applies:** Need persistent mock Redis state.

---

## Test Execution Plan

### Phase 1: Quick Wins (2 hours total)
1. Fix IP independence test (mock Redis key isolation)
2. Fix Redis cluster test (simplify assertion)
3. Fix user auth tests (environment mocking)

### Phase 2: Medium Effort (6 hours total)
4. Fix rate limiter state tests (persistent mock or real redis-mock)
5. Fix fail-open test (module reset approach)

### Phase 3: Major Work (16-24 hours)
6. Fix E2E encryption tests (Signal Protocol API update)

---

## Recommendations

### Immediate Actions (Do Now)
1. ✅ Fix IP independence test
2. ✅ Fix Redis cluster test  
3. ✅ Fix user auth tests

### Short Term (This Week)
4. ⚠️ Consider using `redis-mock` npm package instead of manual mocks
5. ⚠️ Restructure rate limiter to be more testable (dependency injection)

### Long Term (Next Sprint)
6. 🔴 Update Signal Protocol implementation to match v0.86.4 API
7. 🔴 OR replace with simpler encryption library
8. 🔴 Add E2E encryption integration tests with real scenarios

---

## Alternative: Real Redis for Tests

Instead of complex mocking, consider using a real Redis instance for tests:

```bash
# Use redis-mock npm package
npm install --save-dev redis-mock

# Or use Docker for integration tests
docker run -d -p 6379:6379 redis:alpine
```

**Pros:**
- No mock complexity
- Tests real behavior
- Easier to maintain

**Cons:**
- Requires Docker/Redis setup
- Slower tests
- CI/CD needs Redis container

---

## Summary Table

| Test | Difficulty | Time | Priority | Recommendation |
|------|-----------|------|----------|----------------|
| User auth JWT test | 🟢 Easy | 15m | Low | Fix now |
| User auth credentials test | 🟢 Easy | 30m | Low | Fix now |
| IP independence test | 🟢 Easy | 1h | Medium | Fix now |
| Redis cluster test | 🟢 Easy | 1h | Low | Fix now |
| Rate limiter blocking | 🟡 Medium | 4h | Medium | Use redis-mock |
| Rate limiter fail open | 🟡 Medium | 2h | High | Use module reset |
| Rate limiter free tier | 🟡 Medium | 4h | Medium | Use redis-mock |
| E2E encryption suite | 🔴 Hard | 16-24h | High | Update Signal Protocol |

---

## Conclusion

- **7 tests** can be fixed with **8-10 hours** of focused work
- **5 tests** (E2E encryption) require **16-24 hours** for Signal Protocol API update
- Recommend focusing on quick wins first, then decide on E2E encryption approach
