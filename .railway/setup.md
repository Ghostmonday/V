# Railway Auto-Setup Guide

## What's Already Configured ✅

Railway will automatically detect and use:
- ✅ `Dockerfile` - Multi-stage build configuration
- ✅ `railway.json` - Deploy settings, health checks, restart policy
- ✅ `nixpacks.toml` - Build environment (Node 20)
- ✅ `.dockerignore` - Excludes unnecessary files
- ✅ `package.json` - Dependencies and scripts

## One-Time Manual Steps (Required)

### 1. Connect GitHub Repository
1. Go to [railway.app](https://railway.app)
2. Click "New Project" → "Deploy from GitHub repo"
3. Select `Ghostmonday/V` repository
4. Select `main` branch

### 2. Add Database Services
Railway will NOT auto-create databases from config. You must add them manually:

```bash
# Option A: Via Railway Dashboard
1. Click "New" → "Database" → "Add PostgreSQL"
2. Click "New" → "Database" → "Add Redis"

# Option B: Via Railway CLI (faster)
npm install -g @railway/cli
railway login
railway link
railway add --database postgres
railway add --database redis
```

### 3. Set Environment Variables
Add these in Railway dashboard → Variables:

**Auto-filled by Railway:**
- `DATABASE_URL` - ✅ Automatically set when Postgres is added
- `REDIS_URL` - ✅ Automatically set when Redis is added

**You must add manually:**
```bash
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-secret-key
JWT_SECRET=$(openssl rand -base64 32)  # Generate random secret
```

**Optional:**
```bash
DEEPSEEK_API_KEY=your-api-key
```

### 4. Run Database Migration
After first successful deploy:

```bash
# Get DATABASE_URL from Railway dashboard → Postgres → Connect
railway run psql $DATABASE_URL < sql/FRESH_START.sql

# Or manually in Railway's Postgres console
```

## Verification

1. **Check deployment**: Railway → Deployments → View logs
2. **Test health endpoint**: `https://<your-app>.railway.app/health`
3. **Expected response**: `{"status":"ok","timestamp":"..."}`

## Auto-Deploy Triggers

Railway will automatically deploy when you:
- Push to `main` branch
- Merge a PR to `main`
- Manually trigger in Railway dashboard

## Environment Variables Reference

| Variable | Source | Required |
|----------|--------|----------|
| `NODE_ENV` | ✅ Auto (railway.json) | Yes |
| `PORT` | ✅ Auto (railway.json) | Yes |
| `DATABASE_URL` | ✅ Auto (Postgres service) | Yes |
| `REDIS_URL` | ✅ Auto (Redis service) | Yes |
| `NEXT_PUBLIC_SUPABASE_URL` | ⚠️ Manual | Yes |
| `SUPABASE_SERVICE_ROLE_KEY` | ⚠️ Manual | Yes |
| `JWT_SECRET` | ⚠️ Manual | Yes |
| `DEEPSEEK_API_KEY` | ⚠️ Manual | No |

## CLI Quick Setup Script

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and link project
railway login
railway link

# Add databases
railway add --database postgres
railway add --database redis

# Set environment variables
railway variables set NEXT_PUBLIC_SUPABASE_URL="your-url"
railway variables set SUPABASE_SERVICE_ROLE_KEY="your-key"
railway variables set JWT_SECRET="$(openssl rand -base64 32)"

# Deploy
railway up
```

## Troubleshooting

**Build fails:**
- Check Railway logs for TypeScript errors
- Verify `package-lock.json` is committed
- Ensure all dependencies are in `package.json`

**Health check fails:**
- Verify `/health` endpoint returns 200
- Check `DATABASE_URL` and `REDIS_URL` are set
- Review application logs for startup errors

**Database connection errors:**
- Ensure Postgres service is "Ready"
- Verify `DATABASE_URL` is set correctly
- Check migration has been run
