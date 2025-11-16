#!/bin/bash

# Seed script for VibeZ database initialization
# Populates Supabase with initial data and configuration

set -e

# Check for required environment variables
if [ -z "$SUPABASE_HOST" ] || [ -z "$SUPABASE_USER" ] || [ -z "$SUPABASE_DB" ]; then
  echo "Error: SUPABASE_HOST, SUPABASE_USER, and SUPABASE_DB must be set"
  exit 1
fi

# Set PGPASSWORD if provided
if [ -n "$SUPABASE_PASSWORD" ]; then
  export PGPASSWORD="$SUPABASE_PASSWORD"
fi

echo "Running database initialization..."

# Run main schema SQL
if [ -f "sql/sinapse_complete.sql" ]; then
  echo "Applying sinapse_complete.sql..."
  psql -h "$SUPABASE_HOST" -U "$SUPABASE_USER" -d "$SUPABASE_DB" -f sql/sinapse_complete.sql || {
    echo "Warning: sinapse_complete.sql may have already been applied"
  }
fi

# Run healing_logs migration
if [ -f "sql/07_healing_logs.sql" ]; then
  echo "Applying healing_logs migration..."
  psql -h "$SUPABASE_HOST" -U "$SUPABASE_USER" -d "$SUPABASE_DB" -f sql/07_healing_logs.sql || {
    echo "Warning: healing_logs table may already exist"
  }
fi

# Insert default system configuration
echo "Inserting default configuration..."
psql -h "$SUPABASE_HOST" -U "$SUPABASE_USER" -d "$SUPABASE_DB" <<EOF
INSERT INTO system_config (key, value) 
VALUES ('autonomy_mode', '"enabled"') 
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP;
EOF

echo "Database seeding completed successfully!"

