# Railway Environment Variables - Correct Values

## ✅ Correct Environment Variables

### Required Variables:

| Variable | Value | Notes |
|----------|-------|-------|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://nqkxynyplrvopjyffrgy.supabase.co` | ✅ This is your Supabase database URL |
| `SUPABASE_SERVICE_ROLE_KEY` | `sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7` | ✅ Supabase service role key |
| `JWT_SECRET` | `4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw==` | ✅ JWT signing secret |
| `NODE_ENV` | `production` | ✅ **Use `production` for Railway deployments** |
| `REDIS_URL` | `redis://...` | ✅ **Auto-set by Railway** when you add Redis service |

---

## ❌ Common Mistakes

### ❌ WRONG: Using Supabase URL for Redis
```
REDIS_URL=https://nqkxynyplrvopjyffrgy.supabase.co  # ❌ This is Supabase, not Redis!
```

### ✅ CORRECT: Redis URL Format
```
REDIS_URL=redis://default:password@redis.railway.internal:6379  # ✅ Auto-set by Railway
```

### ❌ WRONG: Using development in production
```
NODE_ENV=development  # ❌ Use this only for local development
```

### ✅ CORRECT: Use production for Railway
```
NODE_ENV=production  # ✅ Use this for Railway deployments
```

---

## 🔧 How to Set Up Redis in Railway

1. **Add Redis Service**:
   - Railway Dashboard → Your Project → **"New"** → **"Database"** → **"Add Redis"**
   - Railway automatically creates the Redis service and sets `REDIS_URL`

2. **Verify Redis URL**:
   - Railway Dashboard → Redis Service → **"Variables"** tab
   - You'll see `REDIS_URL` automatically set (format: `redis://...`)

3. **No Manual Setup Needed**:
   - Railway handles Redis connection string automatically
   - Your app will automatically use it via `process.env.REDIS_URL`

---

## 📋 Complete Railway Setup Checklist

### Step 1: Add Services
- [ ] Add **Redis** service (auto-creates `REDIS_URL`)
- [ ] Your app service is already added

### Step 2: Set Environment Variables
In Railway Dashboard → Your App Service → Variables:

- [ ] `NEXT_PUBLIC_SUPABASE_URL` = `https://nqkxynyplrvopjyffrgy.supabase.co`
- [ ] `SUPABASE_SERVICE_ROLE_KEY` = `sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7`
- [ ] `JWT_SECRET` = `4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw==`
- [ ] `NODE_ENV` = `production` ⚠️ **Important: Use `production`, not `development`**
- [ ] `REDIS_URL` = ✅ **Auto-set** (don't set manually)

### Step 3: Deploy
- [ ] Trigger deployment (Railway auto-deploys on push, or click "Redeploy")

---

## 🎯 Summary

1. **Redis**: Add Redis service in Railway → `REDIS_URL` is auto-set (don't use Supabase URL)
2. **NODE_ENV**: Use `production` for Railway deployments (not `development`)

---

## 🔍 Why NODE_ENV=production?

- **Security**: Disables debug logs and verbose error messages
- **Performance**: Enables optimizations and caching
- **Best Practice**: Standard for production deployments
- **Railway**: Recommended setting for all production services

Use `development` only when running locally on your machine.

