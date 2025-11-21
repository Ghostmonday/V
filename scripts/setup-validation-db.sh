#!/bin/bash
# Setup script to initialize validation database with migrations
# This runs after Docker containers are up

set -e

echo "🔧 Setting up validation database..."

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker exec vibez-validation-postgres psql -U vibez -d vibez_validation -c '\q' >/dev/null 2>&1; do
  echo "   PostgreSQL is unavailable - sleeping..."
  sleep 1
done
echo "✅ PostgreSQL is ready!"

# Set connection string (for display only, not used by docker exec)
export DATABASE_URL="postgresql://vibez:vibez_dev_password@localhost:5433/vibez_validation"

# Run migrations in order
echo ""
echo "📦 Running migrations..."

# Helper function to run psql in docker
run_psql_file() {
  local file=$1
  # Strip leading "sql/" and prepend mount point
  local relative_path="${file#sql/}"
  local container_path="/docker-entrypoint-initdb.d/$relative_path"
  
  # Check if file exists in container (it should via volume mount)
  echo "  → Running $relative_path..."
  docker exec vibez-validation-postgres psql -U vibez -d vibez_validation -f "$container_path"
}

# Core schema first
if [ -f "sql/01_sinapse_schema.sql" ]; then
  run_psql_file "sql/01_sinapse_schema.sql"
fi

# Phase 1 migrations
if [ -f "sql/migrations/2025-01-XX-refresh-tokens.sql" ]; then
  run_psql_file "sql/migrations/2025-01-XX-refresh-tokens.sql"
fi

# Phase 3 migrations
if [ -f "sql/migrations/2025-01-XX-phase3-performance-indexes.sql" ]; then
  run_psql_file "sql/migrations/2025-01-XX-phase3-performance-indexes.sql"
fi

if [ -f "sql/migrations/2025-01-XX-phase3-message-archives.sql" ]; then
  run_psql_file "sql/migrations/2025-01-XX-phase3-message-archives.sql"
fi

# Add role column to users if not exists (Phase 1.3)
echo "  → Ensuring role column exists..."
docker exec -i vibez-validation-postgres psql -U vibez -d vibez_validation <<EOF
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

