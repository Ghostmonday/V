# 🔒 SECURITY FIX - STEP-BY-STEP GUIDE

## Overview

This guide walks you through fixing all security gaps in your Supabase schema. **Follow these steps exactly** to secure your database.

---

## ⚠️ BEFORE YOU START

1. **Backup your database** - Always backup before running security fixes
2. **Test in staging first** - Never run security fixes directly in production
3. **Review the audit** - Read `COMPLETE_SECURITY_AUDIT.md` to understand what's being fixed

---

## STEP 1: Review Current Status

Run this query in Supabase SQL Editor to see current RLS status:

```sql
SELECT 
  schemaname,
  tablename,
  CASE 
    WHEN relrowsecurity THEN '✅ RLS ENABLED'
    ELSE '🔴 RLS DISABLED'
  END AS rls_status,
  (SELECT COUNT(*) FROM pg_policies WHERE schemaname = t.schemaname AND tablename = t.tablename) AS policy_count
FROM pg_tables t
LEFT JOIN pg_class c ON c.relname = t.tablename
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.schemaname
WHERE t.schemaname IN ('public', 'service')
  AND t.tablename NOT LIKE 'pg_%'
ORDER BY 
  CASE WHEN relrowsecurity THEN 0 ELSE 1 END,
  t.tablename;
```

**Expected:** You should see many tables with `🔴 RLS DISABLED`

---

## STEP 2: Run the Security Fix Script

1. **Open Supabase Dashboard** → SQL Editor
2. **Copy the entire contents** of `COMPLETE_SECURITY_FIX.sql`
3. **Paste into SQL Editor**
4. **Click "Run"**

**What this does:**
- ✅ Enables RLS on 17+ critical tables
- ✅ Fixes leaky SELECT policies
- ✅ Fixes circular dependencies
- ✅ Fixes SECURITY DEFINER functions
- ✅ Adds admin/mod override policies
- ✅ Adds missing DELETE policies

**Expected runtime:** 5-30 seconds depending on table count

**⚠️ IMPORTANT:** The script is **idempotent** - safe to run multiple times. It uses `DROP POLICY IF EXISTS` and `CREATE POLICY` so it won't break if run twice.

---

## STEP 3: Verify the Fixes

Run the verification script:

1. **Open Supabase Dashboard** → SQL Editor
2. **Copy the entire contents** of `VERIFY_RLS_STATUS.sql`
3. **Paste into SQL Editor**
4. **Click "Run"**

**Check the results:**

### ✅ GOOD Results:
- All tables show `✅ RLS ENABLED`
- Policy count > 0 for all tables
- No tables in "TABLES WITHOUT POLICIES" section
- No leaky policies (except intentional public access)

### 🔴 BAD Results:
- Tables still showing `🔴 RLS DISABLED` → Re-run `COMPLETE_SECURITY_FIX.sql`
- Tables with 0 policies → Check if table exists, may need manual policy creation
- Leaky policies found → Review and fix manually

---

## STEP 4: Test Your Application

After applying fixes, **test your application thoroughly**:

### Test Cases:

1. **User Authentication:**
   - ✅ Users can read their own profile
   - ✅ Users can update their own profile
   - ✅ Users CANNOT read other users' private data

2. **Room Access:**
   - ✅ Users can see public rooms
   - ✅ Users can see rooms they're members of
   - ✅ Users CANNOT see private rooms they're not in

3. **Message Access:**
   - ✅ Users can see messages in rooms they're members of
   - ✅ Users can send messages in rooms they're members of
   - ✅ Users CANNOT see messages in rooms they're not in

4. **Admin/Mod Functions:**
   - ✅ Admins can manage room memberships
   - ✅ Admins can delete/modify messages
   - ✅ Regular users CANNOT perform admin actions

5. **Service Role:**
   - ✅ Service role can access all tables (for backend operations)
   - ✅ Regular users CANNOT access service-only tables

---

## STEP 5: Monitor for Issues

After deployment, monitor for:

1. **Policy Violations:**
   - Check Supabase logs for RLS policy errors
   - Look for `new row violates row-level security policy` errors

2. **Performance:**
   - RLS policies add overhead - monitor query performance
   - Check if indexes are being used (EXPLAIN queries)

3. **User Reports:**
   - Users reporting "access denied" errors
   - Users unable to perform expected actions

---

## TROUBLESHOOTING

### Issue: "Policy already exists" error

**Solution:** This shouldn't happen (script uses `DROP POLICY IF EXISTS`), but if it does:
```sql
DROP POLICY IF EXISTS policy_name ON table_name;
-- Then re-run COMPLETE_SECURITY_FIX.sql
```

### Issue: Users can't access their own data

**Solution:** Check if `auth.uid()` is working:
```sql
SELECT auth.uid(); -- Should return UUID, not NULL
```

If NULL, check:
- User is authenticated (has valid JWT)
- Supabase auth is properly configured
- JWT secret matches between app and Supabase

### Issue: Service role can't access tables

**Solution:** Service role policies should allow full access. Check:
```sql
SELECT * FROM pg_policies 
WHERE tablename = 'your_table' 
AND roles = '{service_role}';
```

### Issue: Circular dependency in room_memberships

**Solution:** Already fixed in `COMPLETE_SECURITY_FIX.sql` - uses EXISTS instead of IN subquery.

---

## WHAT WAS FIXED

### Critical Fixes (17 tables):
1. ✅ `refresh_tokens` - Added RLS + policies
2. ✅ `auth_audit_log` - Added RLS + policies
3. ✅ `flagged_messages` - Added RLS + policies
4. ✅ `message_archives` - Added RLS + policies
5. ✅ `conversations` - Added RLS + policies
6. ✅ `conversation_participants` - Added RLS + policies
7. ✅ `sentiment_analysis` - Added RLS + policies
8. ✅ `cards` - Added RLS + policies
9. ✅ `card_ownerships` - Added RLS + policies
10. ✅ `card_events` - Added RLS + policies
11. ✅ `museum_entries` - Added RLS + policies
12. ✅ `boosts` - Added RLS + policies
13. ✅ `personas` - Added RLS + policies
14. ✅ `invites` - Added RLS + policies
15. ✅ `user_progress` - Added RLS + policies
16. ✅ `scheduled_calls` - Added RLS + policies
17. ✅ `user_subscriptions` - Added RLS + policies

### Policy Fixes:
1. ✅ `users` - Fixed leaky SELECT (now only own + verified)
2. ✅ `rooms` - Fixed SELECT to respect `is_public` flag
3. ✅ `room_memberships` - Fixed circular dependency
4. ✅ `logs_compressed` - Fixed leaky SELECT

### Function Fixes:
1. ✅ `is_room_member()` - Removed unsafe default parameter
2. ✅ `is_room_admin()` - Removed unsafe default parameter

### Added Policies:
1. ✅ Admin/mod override for room management
2. ✅ Admin/mod override for message deletion
3. ✅ DELETE policies for user-owned data
4. ✅ Service role policies for backend operations

---

## SECURITY CHECKLIST

After running fixes, verify:

- [ ] All tables have RLS enabled
- [ ] All tables have at least 1 policy
- [ ] No leaky SELECT policies (except intentional)
- [ ] Users can only access their own data
- [ ] Room members can only access their rooms
- [ ] Admins can perform admin actions
- [ ] Service role can access service tables
- [ ] Immutable tables (audit logs) have no UPDATE/DELETE policies
- [ ] SECURITY DEFINER functions are safe

---

## NEXT STEPS

1. ✅ **Run fixes** - Execute `COMPLETE_SECURITY_FIX.sql`
2. ✅ **Verify** - Run `VERIFY_RLS_STATUS.sql`
3. ✅ **Test** - Test your application thoroughly
4. ✅ **Monitor** - Watch for policy violations
5. ✅ **Document** - Update your security docs

---

## SUPPORT

If you encounter issues:

1. Check `COMPLETE_SECURITY_AUDIT.md` for detailed table analysis
2. Review `VERIFY_RLS_STATUS.sql` output for specific issues
3. Check Supabase logs for RLS policy errors
4. Test with `SELECT auth.uid()` to verify authentication

---

**END OF GUIDE**

**Remember:** Security is an ongoing process. Regularly audit your policies and test your application!

