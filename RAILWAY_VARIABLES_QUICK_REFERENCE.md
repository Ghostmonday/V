# Railway Variables Quick Reference

## ✅ Set as ENVIRONMENT Variables (Not Shared)

In Railway Dashboard → Your Service → **Variables** tab → Click **"New Variable"**

Set these as **Environment** variables (service-specific):

### Required Variables:

| Variable Name | Value | Type |
|--------------|-------|------|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://nqkxynyplrvopjyffrgy.supabase.co` | Environment |
| `SUPABASE_SERVICE_ROLE_KEY` | `sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7` | Environment |
| `JWT_SECRET` | `4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw==` | Environment |
| `NODE_ENV` | `production` | Environment |

### Auto-Set Variables (when you add services):

| Variable Name | How It's Set | Type |
|--------------|--------------|------|
| `REDIS_URL` | Auto-set when you add Redis service | Environment |
| `DATABASE_URL` | Auto-set if you add PostgreSQL (optional - you're using Supabase) | Environment |
| `PORT` | Auto-set by Railway | Environment |

---

## 📋 Step-by-Step in Railway Dashboard

1. Go to [railway.app](https://railway.app)
2. Open your project
3. Click on your **service** (the one deploying the app)
4. Go to **"Variables"** tab
5. Click **"New Variable"** (or **"Raw Editor"** for bulk)
6. Add each variable as **Environment** (not Shared)
7. After adding all 4, **Redeploy** the service

---

## 🔍 How to Verify

After setting variables:
1. Check Variables tab - all 4 should be listed
2. Check they're marked as **Environment** (not Shared)
3. Redeploy → Check logs for successful startup
4. Test: `curl https://your-app.railway.app/health`

---

## ⚠️ Important Notes

- **Environment** = Service-specific (use this)
- **Shared** = Available to all services (not needed for single service)
- Variables are case-sensitive
- No spaces around the `=` sign
- Values with special characters (like `+` in JWT_SECRET) should work fine

