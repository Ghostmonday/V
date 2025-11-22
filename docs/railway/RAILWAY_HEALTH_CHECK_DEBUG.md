# Railway Health Check Debugging Guide

## Current Issue: Health Check Failing

**Status**: Build ✅ succeeded, but health check ❌ failing

**Symptoms**:
- Docker build completes successfully (10.36 seconds)
- Health check attempts fail with "service unavailable"
- Server never responds to `/health` endpoint

---

## 🔍 How to Debug

### Step 1: Check Container Logs (Not Build Logs)

The logs you're seeing are **build logs**. You need to check **runtime/container logs** to see why the server isn't starting.

**In Railway Dashboard:**
1. Go to Railway Dashboard → Your Service
2. Click **"Deployments"** tab
3. Click on the **latest deployment**
4. Look for **"Logs"** or **"Runtime Logs"** (not "Build Logs")
5. Scroll to see what happens when the container starts

**What to look for:**
- ✅ `"Server running on port 3000"` - means server started successfully
- ❌ `"Missing NEXT_PUBLIC_SUPABASE_URL"` - missing environment variable
- ❌ `"Error connecting to Redis"` - Redis connection issue
- ❌ `"Error connecting to Supabase"` - Database connection issue
- ❌ Any uncaught exceptions or errors

---

## 🐛 Common Causes

### 1. Missing Environment Variables (Most Likely)

The server crashes immediately if these are missing:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

**Check**: Railway Dashboard → Variables tab → Verify all 4 required variables are set

### 2. Server Not Starting

Check runtime logs for:
- Port binding errors
- Module import errors
- Database connection failures

### 3. Wrong Port

Verify the server is listening on the port Railway expects:
- Railway sets `PORT` environment variable automatically
- Your code should use: `process.env.PORT || 3000`
- Check logs for: `"Server running on port X"`

---

## 🔧 Quick Fixes

### Fix 1: Verify Environment Variables

In Railway Dashboard → Variables, ensure these are set:

```
NEXT_PUBLIC_SUPABASE_URL=https://nqkxynyplrvopjyffrgy.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7
JWT_SECRET=4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw==
NODE_ENV=production
REDIS_URL=redis://... (auto-set when Redis service is added)
```

### Fix 2: Add Redis Service

If `REDIS_URL` is missing:
1. Railway Dashboard → Your Project → "New" → "Database" → "Add Redis"
2. Railway automatically sets `REDIS_URL`
3. Redeploy

### Fix 3: Check Server Startup Code

The server should:
1. Start listening on `process.env.PORT || 3000`
2. Log `"Server running on port X"` when ready
3. Respond to `/health` endpoint

---

## 📋 Debugging Checklist

- [ ] Check **runtime logs** (not build logs) in Railway Dashboard
- [ ] Verify all **environment variables** are set in Railway Dashboard
- [ ] Verify **Redis service** exists and `REDIS_URL` is auto-set
- [ ] Check if server logs show **"Server running on port X"**
- [ ] Check for **error messages** in runtime logs
- [ ] Verify **health endpoint** exists: `/health` should return `{"status":"ok",...}`

---

## 🎯 Next Steps

1. **Check runtime logs** in Railway Dashboard → Deployments → Latest → Logs
2. **Look for error messages** that explain why the server isn't starting
3. **Share the runtime logs** (not build logs) if you need help debugging

The build is working perfectly - the issue is with the server startup/runtime configuration.

