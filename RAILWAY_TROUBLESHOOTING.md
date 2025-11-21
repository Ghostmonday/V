# Railway Deployment Troubleshooting

## Current Issue: Health Check Failing

**Status**: Build ✅ succeeded, but health check ❌ failing

**Symptoms**:
- Docker build completes successfully
- Container starts but `/health` endpoint returns "service unavailable"
- Health check times out after 1m40s

## Most Likely Causes

### 1. **Missing Environment Variables** (Most Likely)
The server crashes on startup if these are missing:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `REDIS_URL` (should be auto-set if Redis service exists)

**Fix**: Verify in Railway Dashboard → Variables that all are set correctly

### 2. **Server Crashing on Startup**
The `database-config.ts` file throws errors at module load time if env vars are missing, which crashes the server before it can respond to health checks.

**Check**: Look at Railway container logs (not build logs) to see startup errors

### 3. **TypeScript Compilation Errors**
Build succeeded despite TypeScript errors (due to `|| true`). These might cause runtime issues.

**Note**: The build shows many TypeScript errors, but they're being ignored. The server might still run, but some features may not work.

## How to Debug

### Step 1: Check Container Logs (Not Build Logs)
1. Go to Railway Dashboard → Your Service → **Logs** tab
2. Look for:
   - "Server running on port 3000" ✅ (means server started)
   - "Missing NEXT_PUBLIC_SUPABASE_URL" ❌ (means env var missing)
   - Any error messages about database connection
   - Any uncaught exceptions

### Step 2: Verify Environment Variables
In Railway Dashboard → Variables, check these exist:

```
NEXT_PUBLIC_SUPABASE_URL=https://nqkxynyplrvopjyffrgy.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7
JWT_SECRET=4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw==
NODE_ENV=production
REDIS_URL=redis://... (should be auto-set)
```

### Step 3: Test Health Endpoint Manually
Once the container is running, test:
```bash
curl https://your-app.railway.app/health
```

Should return: `{"status":"ok","uptime":1234}`

## Quick Fixes

### If Environment Variables Are Missing:
```bash
railway variables --set "NEXT_PUBLIC_SUPABASE_URL=https://nqkxynyplrvopjyffrgy.supabase.co"
railway variables --set "SUPABASE_SERVICE_ROLE_KEY=sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7"
railway variables --set "JWT_SECRET=4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw=="
railway variables --set "NODE_ENV=production"
```

### If Redis Service Missing:
```bash
railway add --database redis
```

## Next Steps

1. **Check Railway container logs** (not build logs) to see actual startup errors
2. **Verify all environment variables are set** in Railway Dashboard
3. **Ensure Redis service exists** and is running
4. **Redeploy** after fixing variables

The build is working - the issue is runtime/startup configuration.

