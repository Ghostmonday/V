# Docker-Based Validation Setup

This guide explains how to run Phase 1-3 validations in a self-contained Docker environment with PostgreSQL and Redis.

## Quick Start

```bash
# Start containers and run full validation
npm run validate:docker:full

# Or step by step:
npm run validate:docker:up      # Start containers
npm run validate:docker:setup   # Initialize database
npm run validate:docker:run    # Run validations
npm run validate:docker:down    # Stop containers
```

## What's Included

### Docker Compose Services

- **PostgreSQL 16** (port 5433)
  - Database: `vibez_validation`
  - User: `vibez`
  - Password: `vibez_dev_password`

- **Redis 7** (port 6380)
  - Persistent storage enabled
  - AOF (Append Only File) enabled

### Scripts

1. **`scripts/setup-validation-db.sh`**
   - Initializes database schema
   - Runs migrations in correct order
   - Ensures required columns exist

2. **`scripts/run-validation-docker.sh`**
   - Sets environment variables
   - Runs SQL validation
   - Runs TypeScript validation
   - Provides clear output

## Manual Setup

### 1. Start Containers

```bash
docker-compose -f docker-compose.validation.yml up -d
```

### 2. Initialize Database

```bash
./scripts/setup-validation-db.sh
```

This will:

- Wait for PostgreSQL to be ready
- Run core schema (`sql/01_sinapse_schema.sql`)
- Run Phase 1 migrations (refresh tokens)
- Run Phase 3 migrations (indexes, archives)
- Ensure `role` column exists in `users` table

### 3. Run Validations

```bash
./scripts/run-validation-docker.sh
```

Or manually:

```bash
export DATABASE_URL="postgresql://vibez:vibez_dev_password@localhost:5433/vibez_validation"
export REDIS_URL="redis://localhost:6380"

# SQL validation
psql "$DATABASE_URL" -f sql/validate-phases-1-3.sql

# TypeScript validation
npm run validate:phases-1-3
```

## Environment Variables

The validation scripts use these environment variables:

```bash
DATABASE_URL=postgresql://vibez:vibez_dev_password@localhost:5433/vibez_validation
REDIS_URL=redis://localhost:6380
```

For Supabase client compatibility (if needed):

```bash
NEXT_PUBLIC_SUPABASE_URL=http://localhost:5433
SUPABASE_SERVICE_ROLE_KEY=vibez_dev_password
```

## Troubleshooting

### Containers won't start

```bash
# Check if ports are in use
lsof -i :5433  # PostgreSQL
lsof -i :6380  # Redis

# View logs
docker-compose -f docker-compose.validation.yml logs
```

### Database connection errors

```bash
# Test connection manually
psql "postgresql://vibez:vibez_dev_password@localhost:5433/vibez_validation" -c "SELECT 1;"

# Check container health
docker ps | grep vibez-validation
```

### Migration errors

```bash
# Reset database (WARNING: deletes all data)
docker-compose -f docker-compose.validation.yml down -v
docker-compose -f docker-compose.validation.yml up -d
./scripts/setup-validation-db.sh
```

### Redis connection errors

```bash
# Test Redis connection
redis-cli -h localhost -p 6380 ping

# Should return: PONG
```

## Port Conflicts

If you have local PostgreSQL or Redis running:

- **PostgreSQL**: Change port `5433` to something else in `docker-compose.validation.yml`
- **Redis**: Change port `6380` to something else in `docker-compose.validation.yml`

Then update `DATABASE_URL` and `REDIS_URL` accordingly.

## Cleanup

```bash
# Stop containers (keeps data)
npm run validate:docker:down

# Stop and remove volumes (deletes data)
docker-compose -f docker-compose.validation.yml down -v
```

## Integration with CI/CD

You can use this setup in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Start validation services
  run: |
    docker-compose -f docker-compose.validation.yml up -d
    sleep 10
    ./scripts/setup-validation-db.sh

- name: Run validations
  run: |
    export DATABASE_URL="postgresql://vibez:vibez_dev_password@localhost:5433/vibez_validation"
    export REDIS_URL="redis://localhost:6380"
    npm run validate:phases-1-3
    psql "$DATABASE_URL" -f sql/validate-phases-1-3.sql
```

## Next Steps

After running validations:

1. Review `validation-results-phases-1-3.json` for detailed results
2. Check `TEST_RESULTS.md` for summary
3. Fix any failing tests
4. Re-run validations to verify fixes

## Notes

- The Docker setup uses non-standard ports (5433, 6380) to avoid conflicts
- Data persists in Docker volumes between runs
- The setup script is idempotent (safe to run multiple times)
- SQL validation handles missing tables/columns gracefully
