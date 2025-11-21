# Railway Variables - Fix Required

## ⚠️ Issues Found

### Issue 1: REDIS_URL May Be Empty
Your `REDIS_URL` shows "Variable Value" which might mean it's empty or not set.

**Fix**: 
1. Check if `REDIS_URL` has an actual value (click to edit and see)
2. If empty, you need to add a Redis service:
   - Railway Dashboard → Your Project → "New" → "Database" → "Add Redis"
   - Railway will automatically set `REDIS_URL` with the correct value

### Issue 2: Duplicate Variables (Shared + Service-Specific)
You have variables set as BOTH Shared and Service-specific. This can cause confusion.

**Fix**: 
- **Remove Shared variables** (keep only Service-specific/Environment variables)
- For a single service deployment, use **Environment** variables (not Shared)
- Shared variables are only needed if multiple services need the same values

---

## ✅ Correct Setup

### Service-Specific Variables (Environment)
Keep these on your **App Service** → Variables → **Environment** (not Shared):

```
JWT_SECRET=4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw==
NEXT_PUBLIC_SUPABASE_URL=https://nqkxynyplrvopjyffrgy.supabase.co
NODE_ENV=production
SUPABASE_SERVICE_ROLE_KEY=sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7
REDIS_URL=redis://... (auto-set by Railway when Redis service is added)
```

### Shared Variables
**Remove these** if you only have one service (not needed):
- JWT_SECRET (shared)
- NEXT_PUBLIC_SUPABASE_URL (shared)
- NODE_ENV (shared)
- SUPABASE_SERVICE_ROLE_KEY (shared)

---

## 🔧 Step-by-Step Fix

### Step 1: Add Redis Service (if not added)
1. Railway Dashboard → Your Project
2. Click **"New"** → **"Database"** → **"Add Redis"**
3. Railway automatically creates Redis service and sets `REDIS_URL`

### Step 2: Verify REDIS_URL Has Value
1. Railway Dashboard → Your App Service → Variables
2. Find `REDIS_URL`
3. Click to edit and verify it has a value like: `redis://default:password@redis.railway.internal:6379`
4. If empty, Redis service wasn't added correctly

### Step 3: Remove Duplicate Shared Variables
1. Railway Dashboard → Your Project → **"Variables"** tab (project level)
2. Remove Shared variables:
   - JWT_SECRET (shared)
   - NEXT_PUBLIC_SUPABASE_URL (shared)
   - NODE_ENV (shared)
   - SUPABASE_SERVICE_ROLE_KEY (shared)
3. Keep only Service-specific variables

### Step 4: Verify Service-Specific Variables
1. Railway Dashboard → Your **App Service** → **Variables** tab
2. Ensure these are set as **Environment** (not Shared):
   - ✅ JWT_SECRET
   - ✅ NEXT_PUBLIC_SUPABASE_URL
   - ✅ NODE_ENV=production
   - ✅ SUPABASE_SERVICE_ROLE_KEY
   - ✅ REDIS_URL (should be auto-set)

---

## 🎯 Summary

1. **REDIS_URL**: Check if it has a value (should be auto-set when Redis service is added)
2. **Remove Shared variables**: Keep only Service-specific/Environment variables
3. **Add Redis service**: If `REDIS_URL` is empty, add Redis service first
4. **Redeploy**: After fixing variables, trigger a new deployment

---

## ✅ Verification Checklist

- [ ] Redis service exists in Railway project
- [ ] `REDIS_URL` has a value (not empty)
- [ ] Variables are set as **Environment** (not Shared) on App Service
- [ ] No duplicate Shared variables
- [ ] All 5 variables are set: JWT_SECRET, NEXT_PUBLIC_SUPABASE_URL, NODE_ENV, SUPABASE_SERVICE_ROLE_KEY, REDIS_URL

