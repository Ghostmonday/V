# 🚨 CRITICAL: REDIS_URL Still localhost

## Problem
Your `REDIS_URL` is still `redis://localhost:6379` which **won't work** in Railway.

The server is crashing because our code now fails fast if REDIS_URL is localhost.

## Immediate Fix

### Step 1: Check Railway Dashboard
1. Go to **Railway Dashboard** → Your Project "VibeZ deploy"
2. Check if you see a **Redis service** in the services list
3. If you DON'T see Redis service → Go to Step 2
4. If you DO see Redis service → Go to Step 3

### Step 2: Add Redis Service (via Dashboard)
1. Railway Dashboard → Your Project → Click **"New"**
2. Select **"Database"** → **"Add Redis"**
3. Railway will create Redis service and **automatically set REDIS_URL** on your app service
4. Wait a few seconds for Railway to set the variable

### Step 3: If Redis Service Exists But REDIS_URL Wrong
1. Railway Dashboard → **Redis Service** → **Variables** tab
2. Find `REDIS_URL` - copy the value (should be like `redis://default:password@redis.railway.internal:6379`)
3. Railway Dashboard → **Your App Service** (@vibez/api) → **Variables** tab
4. Check if `REDIS_URL` is there
5. If it's `localhost`, delete it - Railway should auto-set it from Redis service
6. If it's missing, Railway should auto-add it (check again in a minute)

### Step 4: Verify REDIS_URL
Run in your terminal:
```bash
railway variables | grep REDIS_URL
```

Should show: `redis://default:password@redis.railway.internal:6379` (or similar Railway internal DNS)

NOT: `redis://localhost:6379`

## Check Runtime Logs
After fixing REDIS_URL, check Railway Dashboard → Deployments → Latest → Runtime Logs

You should see:
- ✅ "Starting server..."
- ✅ "hasRedisUrl: true"
- ✅ "Server started successfully on port 3000"

OR if still wrong:
- ❌ "REDIS_URL not set or using localhost"
- ❌ "REDIS_URL is required. Add Redis service in Railway"

## Summary
**The Redis service wasn't added properly.** Add it via Railway Dashboard, and Railway will automatically set REDIS_URL correctly.

