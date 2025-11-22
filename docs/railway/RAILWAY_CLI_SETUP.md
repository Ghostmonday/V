# Railway CLI Setup Guide

## Quick Setup

Run the complete setup script:

```bash
./scripts/railway-setup-complete.sh
```

This script will:
1. ✅ Check/install Railway CLI
2. ✅ Login to Railway (opens browser)
3. ✅ Link to your project
4. ✅ Add Redis service (auto-sets REDIS_URL)
5. ✅ Set all environment variables
6. ✅ Verify setup

---

## Manual CLI Setup

If you prefer to run commands manually:

### Step 1: Install Railway CLI

```bash
npm install -g @railway/cli
```

### Step 2: Login

```bash
railway login
```

This opens your browser to authenticate.

### Step 3: Link Project

```bash
railway link
```

Select your project from the list.

### Step 4: Add Redis Service

```bash
railway add --database redis
```

This automatically sets `REDIS_URL`.

### Step 5: Set Environment Variables

```bash
# Supabase URL
railway variables --set "NEXT_PUBLIC_SUPABASE_URL=https://nqkxynyplrvopjyffrgy.supabase.co"

# Supabase Service Role Key
railway variables --set "SUPABASE_SERVICE_ROLE_KEY=sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7"

# JWT Secret
railway variables --set "JWT_SECRET=4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw=="

# Node Environment
railway variables --set "NODE_ENV=production"
```

### Step 6: Verify Variables

```bash
railway variables
```

Should show all 5 variables:
- ✅ NEXT_PUBLIC_SUPABASE_URL
- ✅ SUPABASE_SERVICE_ROLE_KEY
- ✅ JWT_SECRET
- ✅ NODE_ENV
- ✅ REDIS_URL (auto-set by Redis service)

### Step 7: Deploy

```bash
railway up
```

Or Railway will auto-deploy on git push.

---

## Useful CLI Commands

```bash
# Check status
railway status

# View variables
railway variables

# View logs
railway logs

# Open app in browser
railway open

# Deploy
railway up

# View service info
railway service

# View deployments
railway deployments
```

---

## Troubleshooting

### "Not logged in"
```bash
railway login
```

### "Project not linked"
```bash
railway link
```

### "Redis service not found"
```bash
railway add --database redis
```

### Check REDIS_URL
```bash
railway variables | grep REDIS_URL
```

Should show something like: `redis://default:password@redis.railway.internal:6379`

---

## Summary

1. Run `./scripts/railway-setup-complete.sh` OR
2. Follow manual steps above
3. Verify with `railway variables`
4. Deploy with `railway up` or push to git

