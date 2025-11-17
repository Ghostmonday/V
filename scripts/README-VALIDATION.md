# Phase 1-3 Validation Guide

This guide explains how to validate that phases 1, 2, and 3 are complete.

## Quick Start

```bash
# 1. Run automated TypeScript validation
tsx scripts/validate-phases-1-3.ts

# 2. Run SQL database validation
psql $DATABASE_URL -f sql/validate-phases-1-3.sql

# 3. Review results
cat validation-results-phases-1-3.json
```

## Prerequisites

- Node.js 18+ with `tsx` installed (`npm install -g tsx` or `npm install tsx`)
- PostgreSQL client (`psql`) or Supabase CLI
- Redis running (for some tests)
- Environment variables configured (see `.env`)

## What Gets Validated

### Phase 1: Security & Authentication

- ✅ Refresh token rotation and security
- ✅ Password hashing (no plaintext)
- ✅ Role-based access control (RBAC)
- ✅ Brute-force protection
- ✅ HTTPS/TLS enforcement

### Phase 2: WebSocket & Messaging

- ✅ Message rate limiting
- ✅ Connection health & scaling
- ✅ Delivery acknowledgements
- ✅ WebSocket scaling (Redis pub/sub)

### Phase 3: Database & Performance

- ✅ Performance indexes
- ✅ Query pagination
- ✅ Message archival
- ✅ Redis caching

## Output

The validation script generates:

- **Console output**: Real-time test results with ✅/❌ indicators
- **JSON report**: `validation-results-phases-1-3.json` with detailed results
- **SQL output**: Database validation results in console

## Troubleshooting

### TypeScript Errors

If you see TypeScript errors about Node.js types, they won't prevent execution. The script uses `tsx` which handles types at runtime. To fix:

```bash
npm install --save-dev @types/node
```

### Database Connection

Ensure your database connection is configured:

```bash
export DATABASE_URL="postgresql://user:pass@host:5432/dbname"
# Or use Supabase connection string
```

### Redis Connection

Ensure Redis is running:

```bash
redis-cli ping
# Should return: PONG
```

## Manual Validation

For comprehensive validation, see `VALIDATION_CHECKLIST.md` in the root directory. It includes:

- Manual test procedures
- API endpoint testing
- WebSocket testing
- Performance benchmarks

## Next Steps

After validation:

1. Review any failed tests
2. Fix issues and re-run validation
3. Update BUILD.plan with completion status
4. Proceed to Phase 4 (AI & VIBES Features)
