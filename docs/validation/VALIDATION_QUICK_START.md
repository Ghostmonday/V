# Phase 1-3 Validation Quick Start

**Status:** ✅ Ready to Run  
**Last Updated:** 2025-01-XX

## 🚀 Quick Start (All-in-One)

```bash
# Run all validations at once
./scripts/run-all-validations.sh
```

## 📋 Prerequisites

- **Node.js 18+** with `tsx` (or use `npx tsx`)
- **PostgreSQL client** (`psql`) - optional but recommended
- **Redis** - optional, for Redis-related checks
- **Environment variables** - see below

## 🔧 Setup

### 1. Environment Variables

```bash
# Required for database validation
export DATABASE_URL="postgresql://user:pass@host:5432/dbname"

# Or use Supabase connection string
export DATABASE_URL="postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres"

# Optional - for full validation
export NEXT_PUBLIC_SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-key"
export REDIS_URL="redis://localhost:6379"
```

### 2. Install Dependencies

```bash
# Install tsx if not already installed
npm install -g tsx
# OR use npx (no installation needed)
```

## 🎯 Running Validations

### Option 1: All-in-One Script (Recommended)

```bash
./scripts/run-all-validations.sh
```

This runs:
- ✅ TypeScript validation (code structure, implementations)
- ✅ SQL validation (database schema, data integrity)
- ✅ Generates summary report

### Option 2: Individual Scripts

```bash
# 1. TypeScript validation
npx tsx scripts/validate-phases-1-3.ts

# 2. SQL validation
psql $DATABASE_URL -f sql/validate-phases-1-3.sql

# 3. Review results
cat validation-results-phases-1-3.json
```

### Option 3: Manual Validation

See `VALIDATION_CHECKLIST.md` for step-by-step manual tests.

## 📊 What Gets Validated

### Phase 1: Security & Authentication ✅
- [x] Refresh token rotation & security
- [x] Password hashing (no plaintext)
- [x] Role-based access control (RBAC)
- [x] Brute-force protection
- [x] HTTPS/TLS enforcement

### Phase 2: WebSocket & Messaging ✅
- [x] Message rate limiting
- [x] Connection health & scaling
- [x] Delivery acknowledgements
- [x] WebSocket scaling (Redis pub/sub)

### Phase 3: Database & Performance ✅
- [x] Performance indexes
- [x] Query pagination
- [x] Message archival
- [x] Redis caching

## 📄 Output Files

After running validations:

- **`validation-results-phases-1-3.json`** - Detailed JSON results
- **Console output** - Real-time validation results with ✅/❌ indicators
- **SQL output** - Database validation messages

## 🔍 Understanding Results

### ✅ Passed
- Feature is implemented correctly
- Database schema is correct
- Code structure is valid

### ❌ Failed
- Feature missing or incomplete
- Database schema issue
- Code implementation issue

### ⚠️ Warning
- Partial implementation
- Optional feature missing
- Configuration needed

## 🐛 Troubleshooting

### "tsx not found"
```bash
npm install -g tsx
# OR use npx
npx tsx scripts/validate-phases-1-3.ts
```

### "Database connection failed"
```bash
# Check DATABASE_URL is set
echo $DATABASE_URL

# Test connection
psql $DATABASE_URL -c "SELECT 1;"
```

### "Redis not available"
- Redis checks will be skipped if Redis is not running
- This is OK for initial validation
- Start Redis for full validation: `redis-server`

### "Table/column does not exist"
- This is expected if migrations haven't been run
- Run the suggested migrations from the error messages
- Or check `sql/migrations/` for migration files

## 📚 Next Steps

1. **Review Results** - Check `validation-results-phases-1-3.json`
2. **Fix Issues** - Address any ❌ failures
3. **Run Migrations** - Apply missing database migrations
4. **Re-run Validation** - Verify fixes
5. **Update BUILD.plan** - Mark completed phases

## 📖 Additional Resources

- **Full Checklist:** `VALIDATION_CHECKLIST.md`
- **Summary:** `VALIDATION_SUMMARY.md`
- **Build Plan:** `BUILD.plan`
- **Quick Guide:** `scripts/README-VALIDATION.md`

---

**Ready to validate? Run:**
```bash
./scripts/run-all-validations.sh
```

