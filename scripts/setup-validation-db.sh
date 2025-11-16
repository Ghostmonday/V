#!/bin/bash
# Setup script to initialize validation database with migrations
# This runs after Docker containers are up

set -e

echo "🔧 Setting up validation database..."

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until PGPASSWORD=vibez_dev_password psql -h localhost -p 5433 -U vibez -d vibez_validation -c '\q' 2>/dev/null; do
  echo "   PostgreSQL is unavailable - sleeping..."
  sleep 1
done
echo "✅ PostgreSQL is ready!"

# Set connection string
export DATABASE_URL="postgresql://vibez:vibez_dev_password@localhost:5433/vibez_validation"

# Run migrations in order
echo ""
echo "📦 Running migrations..."

# Core schema first
if [ -f "sql/01_sinapse_schema.sql" ]; then
  echo "  → Running core schema..."
  psql "$DATABASE_URL" -f sql/01_sinapse_schema.sql
fi

# Phase 1 migrations
if [ -f "sql/migrations/2025-01-XX-refresh-tokens.sql" ]; then
  echo "  → Running refresh tokens migration..."
  psql "$DATABASE_URL" -f sql/migrations/2025-01-XX-refresh-tokens.sql
fi

# Phase 3 migrations
if [ -f "sql/migrations/2025-01-XX-phase3-performance-indexes.sql" ]; then
  echo "  → Running performance indexes migration..."
  psql "$DATABASE_URL" -f sql/migrations/2025-01-XX-phase3-performance-indexes.sql
fi

if [ -f "sql/migrations/2025-01-XX-phase3-message-archives.sql" ]; then
  echo "  → Running message archives migration..."
  psql "$DATABASE_URL" -f sql/migrations/2025-01-XX-phase3-message-archives.sql
fi

# Add role column to users if not exists (Phase 1.3)
echo "  → Ensuring role column exists..."
psql "$DATABASE_URL" <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'role'
  ) THEN
    ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user';
    RAISE NOTICE 'Added role column to users table';
  ELSE
    RAISE NOTICE 'Role column already exists';
  END IF;
END \$\$;
EOF

echo ""
echo "✅ Database setup complete!"
echo ""
echo "Connection details:"
echo "  DATABASE_URL=postgresql://vibez:vibez_dev_password@localhost:5433/vibez_validation"
echo "  REDIS_URL=redis://localhost:6380"
echo ""
echo "Run validations with:"
echo "  npm run validate:phases-1-3:docker"

