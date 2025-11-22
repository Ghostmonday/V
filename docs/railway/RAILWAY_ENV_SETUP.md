# Railway Environment Variables Setup

## Your Credentials (Ready to Use)

✅ **Supabase URL**: `https://nqkxynyplrvopjyffrgy.supabase.co`  
✅ **Supabase Service Role Key**: `sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7`  
✅ **JWT Secret**: `4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw==`

---

## Option 1: Railway Dashboard (Easiest)

1. Go to [railway.app](https://railway.app)
2. Open your project → Your service
3. Go to **"Variables"** tab
4. Click **"New Variable"** and add each:

   | Variable Name | Value |
   |--------------|-------|
   | `NEXT_PUBLIC_SUPABASE_URL` | `https://nqkxynyplrvopjyffrgy.supabase.co` |
   | `SUPABASE_SERVICE_ROLE_KEY` | `sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7` |
   | `JWT_SECRET` | `4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw==` |
   | `NODE_ENV` | `production` |

5. **Add Redis service** if not already added:
   - Click "New" → "Database" → "Add Redis"
   - This auto-creates `REDIS_URL`

6. **Trigger deployment**:
   - Go to "Deployments" → Click "Redeploy"

---

## Option 2: Railway CLI (Faster)

```bash
# 1. Login (opens browser)
railway login

# 2. Link to your project
railway link

# 3. Run the setup script
./scripts/set-railway-env.sh

# 4. Add Redis if not already added
railway add --database redis

# 5. Deploy
railway up
```

---

## Option 3: Manual CLI Commands

```bash
# Login and link
railway login
railway link

# Set variables
railway variables set NEXT_PUBLIC_SUPABASE_URL="https://nqkxynyplrvopjyffrgy.supabase.co"
railway variables set SUPABASE_SERVICE_ROLE_KEY="sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7"
railway variables set JWT_SECRET="4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw=="
railway variables set NODE_ENV="production"

# Add Redis
railway add --database redis

# Deploy
railway up
```

---

## Verify Variables Are Set

```bash
railway variables
```

Should show all 4 variables listed above.

---

## After Setting Variables

1. ✅ Variables are set
2. ✅ Redis service is added (creates `REDIS_URL` automatically)
3. ✅ Trigger deployment (Dashboard → Deployments → Redeploy)
4. ✅ Check logs for successful startup
5. ✅ Test health endpoint: `https://your-app.railway.app/health`

---

## Security Note

⚠️ These credentials are now in this file. After setting them in Railway:
- Consider removing sensitive values from this file
- Or add this file to `.gitignore` if you want to keep it local only

