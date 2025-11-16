#!/bin/bash
# VIBES Migration Script
# Migrates existing VibeZ database to VIBES schema

set -e

echo "🔄 VIBES Migration Script"
echo ""

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
  echo "❌ Error: DATABASE_URL environment variable not set"
  exit 1
fi

echo "📊 Step 1: Running VIBES schema migration..."
psql $DATABASE_URL -f sql/migrations/2025-11-15-vibes-core-schema.sql

echo ""
echo "✅ Migration complete!"
echo ""
echo "Next steps:"
echo "1. Verify tables created: SELECT table_name FROM information_schema.tables WHERE table_name LIKE '%card%' OR table_name LIKE '%conversation%';"
echo "2. Test API endpoints"
echo "3. Enable card generation: Set CARD_GENERATION_ENABLED=true in .env"
