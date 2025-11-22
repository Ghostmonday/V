# How to Get REDIS_URL from Railway Dashboard

## Step-by-Step

### Step 1: Go to Redis Service Variables
1. Railway Dashboard → Your Project "VibeZ deploy"
2. Click on the **Redis service** (not your app service)
3. Click **"Variables"** tab (or "Connect" tab)

### Step 2: Find REDIS_URL
Look for a variable called `REDIS_URL` - it should show something like:
```
redis://default:password@redis.railway.internal:6379
```
or
```
redis://default:password@containers-us-west-xxx.railway.app:6379
```

### Step 3: Copy the Value
Copy the entire `REDIS_URL` value (the connection string)

### Step 4: Set It on Your App Service
1. Go back to Railway Dashboard → Your **App Service** (@vibez/api)
2. Click **"Variables"** tab
3. Find `REDIS_URL` (currently shows `redis://localhost:6379`)
4. Click to edit it
5. Paste the correct value from Redis service
6. Save

### Step 5: Verify
Run in terminal:
```bash
railway variables | grep REDIS_URL
```

Should show the Railway internal DNS (NOT localhost)

---

## Alternative: Railway Should Auto-Set It

If Redis service is properly connected to your app service, Railway should automatically set `REDIS_URL` on your app service.

**Check:**
1. Railway Dashboard → Your App Service → Variables
2. Look for `REDIS_URL` - if it's still localhost, Railway didn't auto-set it
3. Manually copy from Redis service → Variables → REDIS_URL

---

## Quick Fix Command

After getting REDIS_URL from Redis service, run:
```bash
railway variables --set "REDIS_URL=<paste-value-here>"
```

Replace `<paste-value-here>` with the actual REDIS_URL from Redis service.



