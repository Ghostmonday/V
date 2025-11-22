# Railway Debugging: Variables Set But Health Check Failing

## ✅ Variables Are Set - Next Steps

Since environment variables are set, let's debug why the health check is still failing.

---

## 🔍 Step 1: Check Runtime Logs (Not Build Logs)

**Critical**: You need to check **runtime/container logs**, not build logs.

**In Railway Dashboard:**
1. Go to Railway Dashboard → Your Service
2. Click **"Deployments"** tab
3. Click on the **latest deployment**
4. Look for **"Logs"** or **"Runtime Logs"** section
5. Scroll to see what happens **after** the build completes

**What to look for:**
- ✅ `"Server running on port 3000"` - Server started successfully
- ❌ `"Missing NEXT_PUBLIC_SUPABASE_URL"` - Variable not reaching container
- ❌ `"Error connecting to Redis"` - Redis connection issue
- ❌ `"Error connecting to Supabase"` - Database connection issue
- ❌ Any uncaught exceptions or stack traces

---

## 🔍 Step 2: Verify Variables Are Actually Reaching the Container

Even if variables are set in Railway Dashboard, they might not be reaching the container.

**Check variable names match exactly:**
- `NEXT_PUBLIC_SUPABASE_URL` (not `SUPABASE_URL`)
- `SUPABASE_SERVICE_ROLE_KEY` (not `SUPABASE_KEY`)
- `JWT_SECRET`
- `NODE_ENV=production`
- `REDIS_URL` (auto-set when Redis service exists)

**Verify in Railway:**
1. Railway Dashboard → Your Service → **Variables** tab
2. Check each variable:
   - Name matches exactly (case-sensitive)
   - Value is correct (no extra spaces)
   - Type is **Environment** (not Shared)

---

## 🔍 Step 3: Check Redis Service

The `/healthz` endpoint checks both PostgreSQL and Redis. If Redis is missing:

**Add Redis Service:**
1. Railway Dashboard → Your Project → **"New"** → **"Database"** → **"Add Redis"**
2. Railway automatically sets `REDIS_URL`
3. Redeploy

**Note**: The basic `/health` endpoint (used by Railway) doesn't check Redis, but if your server tries to connect to Redis on startup and fails, it might crash.

---

## 🔍 Step 4: Check Server Startup Code

The server should:
1. Start listening on `process.env.PORT || 3000`
2. Log `"Server running on port X"` when ready
3. Respond to `/health` endpoint

**Check if server is starting:**
Look in runtime logs for:
- `"Server running on port 3000"` ✅
- Any error messages before this line ❌

---

## 🐛 Common Issues When Variables Are Set

### Issue 1: Variables Set But Wrong Service
- Variables might be set on the wrong service
- Check: Railway Dashboard → Your **App Service** (not Redis service) → Variables

### Issue 2: Variables Set But Wrong Environment
- Variables might be set for a different environment
- Check: Railway Dashboard → Your Service → Variables → Check environment dropdown

### Issue 3: Server Crashes Before Health Check
- Server might crash immediately on startup
- Check runtime logs for error messages

### Issue 4: Redis Connection Fails
- Server tries to connect to Redis on startup
- If Redis service doesn't exist, connection might timeout/crash
- Solution: Add Redis service or make Redis connection optional

### Issue 5: Database Connection Fails
- Supabase URL or key might be incorrect
- Network/firewall issues
- Check runtime logs for connection errors

---

## 🔧 Quick Fixes

### Fix 1: Verify All Variables
Double-check in Railway Dashboard → Variables:
```
NEXT_PUBLIC_SUPABASE_URL=https://nqkxynyplrvopjyffrgy.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7
JWT_SECRET=4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw==
NODE_ENV=production
REDIS_URL=redis://... (auto-set)
```

### Fix 2: Add Redis Service
If Redis service doesn't exist:
1. Railway Dashboard → Your Project → "New" → "Database" → "Add Redis"
2. Redeploy

### Fix 3: Check Runtime Logs
Share the runtime logs (not build logs) to see the exact error.

---

## 📋 Debugging Checklist

- [ ] Checked **runtime logs** (not build logs) in Railway Dashboard
- [ ] Verified variables are set on **correct service** (App service, not Redis)
- [ ] Verified variables are set for **correct environment**
- [ ] Verified variable **names match exactly** (case-sensitive)
- [ ] Verified variable **values are correct** (no extra spaces)
- [ ] Verified **Redis service exists** and `REDIS_URL` is auto-set
- [ ] Looked for `"Server running on port X"` in runtime logs
- [ ] Looked for **error messages** in runtime logs

---

## 🎯 Next Steps

1. **Check runtime logs** - This will show the exact error
2. **Verify Redis service exists** - Add it if missing
3. **Double-check variable names** - Must match exactly
4. **Share runtime logs** if you need help debugging further

The build is working - the issue is with the server startup/runtime. The runtime logs will tell us exactly what's wrong.

