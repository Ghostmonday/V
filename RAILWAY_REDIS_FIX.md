# Railway Redis URL Fix

## ❌ Problem: `redis://localhost:6379` Won't Work

You have `REDIS_URL=redis://localhost:6379` set, but this **won't work** in Railway because:

- ❌ `localhost` refers to the container itself, not the Redis service
- ❌ Railway services communicate via **internal DNS names**, not localhost
- ❌ The Redis service is in a separate container/service

---

## ✅ Solution: Add Redis Service in Railway

Railway will automatically set `REDIS_URL` with the correct internal connection string when you add a Redis service.

### Step 1: Add Redis Service

1. Go to **Railway Dashboard** → Your Project
2. Click **"New"** button
3. Select **"Database"** → **"Add Redis"**
4. Railway will create a Redis service and automatically set `REDIS_URL`

### Step 2: Verify REDIS_URL is Auto-Set

After adding Redis service:

1. Go to Railway Dashboard → Your **App Service** → **Variables** tab
2. Look for `REDIS_URL`
3. It should now show something like:
   ```
   redis://default:password@redis.railway.internal:6379
   ```
   or
   ```
   redis://default:password@containers-us-west-xxx.railway.app:6379
   ```

### Step 3: Remove Manual REDIS_URL (if you set it manually)

If you manually set `REDIS_URL=redis://localhost:6379`:

1. Railway Dashboard → Your App Service → Variables
2. Find `REDIS_URL`
3. **Delete it** (Railway will auto-set it from the Redis service)
4. Or let Railway override it automatically

---

## 🔍 How Railway Sets REDIS_URL

When you add a Redis service:

1. Railway creates a Redis container/service
2. Railway automatically creates a **reference variable** `REDIS_URL` on your App Service
3. The value points to the Redis service's internal DNS name
4. Your app can now connect to Redis using this URL

**You don't need to set `REDIS_URL` manually** - Railway does it automatically!

---

## ✅ Correct Setup

### Before (Wrong):
```
REDIS_URL=redis://localhost:6379  ❌ Won't work
```

### After (Correct):
```
REDIS_URL=redis://default:password@redis.railway.internal:6379  ✅ Auto-set by Railway
```

---

## 🎯 Summary

1. **Add Redis service** in Railway Dashboard
2. **Railway automatically sets** `REDIS_URL` with correct internal DNS
3. **Remove manual** `REDIS_URL=localhost` if you set it
4. **Redeploy** after adding Redis service

---

## 🔧 If Redis Service Already Exists

If you already have a Redis service but `REDIS_URL` still shows `localhost`:

1. Check if Redis service exists: Railway Dashboard → Your Project → Services
2. If Redis service exists, `REDIS_URL` should be auto-set
3. If it's not auto-set, check:
   - Is Redis service in the same project?
   - Is Redis service running?
   - Try removing and re-adding Redis service

---

## 📋 Verification Checklist

- [ ] Redis service added in Railway project
- [ ] `REDIS_URL` shows Railway internal DNS (not localhost)
- [ ] `REDIS_URL` format: `redis://...@...railway...:6379`
- [ ] No manual `REDIS_URL=localhost` set
- [ ] Redeployed after adding Redis service

