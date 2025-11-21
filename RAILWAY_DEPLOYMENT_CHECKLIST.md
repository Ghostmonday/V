# Railway Deployment Checklist

## 🔴 CRITICAL: Required Environment Variables

Based on the code analysis, these **MUST** be set in Railway or the app will crash on startup:

### Required (App will crash without these):
1. ✅ `NEXT_PUBLIC_SUPABASE_URL` - Your Supabase project URL
   - Example: `https://xxxxx.supabase.co`
   - Get from: Supabase Dashboard → Project Settings → API → Project URL

2. ✅ `SUPABASE_SERVICE_ROLE_KEY` - Your Supabase service role key (secret)
   - Get from: Supabase Dashboard → Project Settings → API → service_role key
   - ⚠️ **SECURITY**: This is a secret key - never commit it

3. ✅ `REDIS_URL` - Redis connection string
   - Auto-set by Railway when you add Redis service
   - Format: `redis://default:password@host:port`
   - If not auto-set, Railway will show it in Redis service → Connect

### Optional (Has defaults but recommended):
4. `JWT_SECRET` - For JWT token signing
   - Generate: `openssl rand -base64 32`
   - Must be at least 32 characters

5. `PORT` - Server port (defaults to 3000)
   - Railway auto-sets this, but you can override

6. `NODE_ENV` - Environment (defaults to development)
   - Should be `production` for Railway

---

## 🚀 How to Check What's Wrong

### Step 1: Check Railway Dashboard
1. Go to [railway.app](https://railway.app)
2. Open your project
3. Click on your service
4. Go to **"Variables"** tab
5. Check if these are set:
   - ✅ `NEXT_PUBLIC_SUPABASE_URL`
   - ✅ `SUPABASE_SERVICE_ROLE_KEY`
   - ✅ `REDIS_URL` (should be auto-set if Redis service exists)

### Step 2: Check Services
1. In Railway dashboard, check if you have:
   - ✅ **PostgreSQL** service (optional - if using Supabase, you might not need this)
   - ✅ **Redis** service (required)

### Step 3: Check Deployment Status
1. Go to **"Deployments"** tab
2. Look at the latest deployment:
   - If it says "Waiting" → Click "Redeploy" or "Deploy"
   - If it failed → Check logs for errors
   - If it's building → Wait for it to complete

---

## 🔧 Quick Fix Commands

If you have Railway CLI access (requires interactive login):

```bash
# 1. Login (opens browser)
railway login

# 2. Link to project
railway link

# 3. Check current variables
railway variables

# 4. Set missing variables
railway variables set NEXT_PUBLIC_SUPABASE_URL="https://your-project.supabase.co"
railway variables set SUPABASE_SERVICE_ROLE_KEY="your-secret-key"
railway variables set JWT_SECRET="$(openssl rand -base64 32)"

# 5. Add Redis if missing
railway add --database redis

# 6. Trigger deployment
railway up
```

---

## 📋 Common Issues

### Issue 1: "Deployment Waiting"
**Cause**: Railway might be waiting for:
- Manual trigger
- Environment variables to be set
- Services to be ready

**Fix**: 
- Go to Railway Dashboard → Deployments → Click "Redeploy"
- Or set missing environment variables first

### Issue 2: "Build Failed - Python not found"
**Status**: ✅ FIXED - We added Python and build tools to Dockerfile

### Issue 3: "App crashes on startup"
**Cause**: Missing required environment variables

**Fix**: Set all required variables listed above

### Issue 4: "Cannot connect to database"
**Cause**: 
- `NEXT_PUBLIC_SUPABASE_URL` not set or incorrect
- `SUPABASE_SERVICE_ROLE_KEY` not set or incorrect

**Fix**: Verify Supabase credentials in Railway Variables

---

## ✅ Verification Steps

After deployment succeeds:

1. **Check Health Endpoint**:
   ```bash
   curl https://your-app.railway.app/health
   ```
   Should return: `{"status":"ok","timestamp":"..."}`

2. **Check Logs**:
   - Railway Dashboard → Service → Logs
   - Should see: "Server starting...", "Connected to database", etc.
   - Should NOT see: "Missing NEXT_PUBLIC_SUPABASE_URL" or similar errors

3. **Check Container Status**:
   - Railway Dashboard → Service → Metrics
   - Container should be "Running" (not restarting)

---

## 🎯 Next Steps

1. **Set Required Variables** in Railway Dashboard
2. **Add Redis Service** if not already added
3. **Trigger Deployment** manually if it's waiting
4. **Check Logs** after deployment to verify startup
5. **Test Health Endpoint** to confirm it's working

---

## 📞 Still Having Issues?

Check the Railway deployment logs for:
- Error messages about missing environment variables
- Database connection errors
- Build errors (should be fixed now)
- Runtime errors

The most common issue is missing `NEXT_PUBLIC_SUPABASE_URL` or `SUPABASE_SERVICE_ROLE_KEY`.

