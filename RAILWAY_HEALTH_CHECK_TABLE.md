# Railway Health Check - Table Verification

## Health Check Query

The health check endpoint (`/health`) queries the **`users`** table:

```sql
SELECT id FROM users LIMIT 1
```

This is the minimal query to verify database connectivity. It:
- ✅ Checks if the database is reachable
- ✅ Verifies the `users` table exists
- ✅ Confirms basic query execution works
- ✅ Returns minimal data (just one ID)

---

## Required Table: `users`

The health check requires:
- **Table name**: `users`
- **Schema**: `public`
- **Required column**: `id` (any type: UUID, TEXT, INTEGER, etc.)
- **Data**: Table can be empty (health check still works)

---

## Verification SQL

Run this SQL in your Supabase SQL Editor to verify the table exists:

```sql
-- Quick check: Does users table exist?
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'users'
        ) 
        THEN '✅ users table exists'
        ELSE '❌ users table NOT found'
    END AS status;

-- Test the actual health check query
SELECT id FROM users LIMIT 1;
```

**Expected result:**
- If table exists: Returns one row with an `id` (or empty result if table is empty)
- If table doesn't exist: Error `relation "public.users" does not exist`

---

## Full Verification Script

See `sql/verify-health-check-table.sql` for a complete verification script that:
1. Checks if `users` table exists
2. Verifies `id` column exists
3. Tests the actual health check query
4. Shows table row count
5. Provides summary status

**To run:**
```bash
# Via Supabase Dashboard:
# 1. Go to SQL Editor
# 2. Paste contents of sql/verify-health-check-table.sql
# 3. Run query

# Via psql:
psql $SUPABASE_DB_URL -f sql/verify-health-check-table.sql
```

---

## If Table Doesn't Exist

If the `users` table is missing, you need to run your database migrations:

1. **Check migration files**: Look in `sql/` directory
2. **Run core schema**: `sql/01_sinapse_schema.sql` (creates users table)
3. **Run migrations**: All files in `sql/migrations/` directory

**Quick fix:**
```sql
-- Create minimal users table for health check
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now()
);
```

---

## Health Check Endpoints

Your app has multiple health check endpoints:

| Endpoint | Description | Checks |
|----------|-------------|--------|
| `/health` | Basic health | Returns `{"status":"ok"}` (no DB check) |
| `/healthz` | Full health | Checks PostgreSQL + Redis |
| `/admin/health` | Admin health | Checks Supabase connectivity |

**Railway uses**: `/health` (configured in `railway.json`)

---

## Troubleshooting

### Error: `relation "public.users" does not exist`
**Fix**: Run database migrations to create the `users` table

### Error: `column "id" does not exist`
**Fix**: The `users` table exists but doesn't have an `id` column. Check your schema.

### Health check passes but app still fails
**Check**: 
- Environment variables are set correctly
- Redis service is added (for `/healthz` endpoint)
- Server logs for other errors

---

## Summary

✅ **Required**: `users` table in `public` schema with `id` column  
✅ **Health check query**: `SELECT id FROM users LIMIT 1`  
✅ **Table can be empty**: Health check works even if no users exist  
✅ **Verification**: Run `sql/verify-health-check-table.sql` to check

