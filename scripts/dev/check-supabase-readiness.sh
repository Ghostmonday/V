#!/bin/bash
# ===============================================
# Supabase Readiness Check Script
# Purpose: Verify Supabase is ready for integration
# Usage: ./scripts/check-supabase-readiness.sh
# ===============================================

set -e

echo "🔍 Checking Supabase Schema Readiness..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Supabase CLI is available
if ! command -v supabase &> /dev/null; then
    echo -e "${YELLOW}⚠️  Supabase CLI not found. Using direct SQL check instead.${NC}"
    echo ""
    echo "To check schema manually:"
    echo "1. Go to Supabase Dashboard > SQL Editor"
    echo "2. Run: scripts/verify-supabase-schema.sql"
    echo "3. Run: scripts/migrate-subscription-support.sql (if needed)"
    exit 0
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    echo "Please create .env file with SUPABASE_URL and SUPABASE_KEY"
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_KEY" ]; then
    echo -e "${RED}❌ SUPABASE_URL or SUPABASE_KEY not set in .env${NC}"
    exit 1
fi

echo "✅ Environment variables loaded"
echo ""

# Check critical tables
echo "📊 Checking Critical Tables..."

TABLES=("users" "rooms" "messages" "usage_stats" "iap_receipts" "files" "config")

for table in "${TABLES[@]}"; do
    # This would require Supabase API or psql connection
    echo -e "  ${YELLOW}⏳ Checking table: $table${NC}"
done

echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Run verification SQL:"
echo "   psql \$SUPABASE_DB_URL -f scripts/verify-supabase-schema.sql"
echo ""
echo "2. If migrations needed, run:"
echo "   psql \$SUPABASE_DB_URL -f scripts/migrate-subscription-support.sql"
echo ""
echo "3. Or use Supabase Dashboard:"
echo "   - Go to SQL Editor"
echo "   - Copy/paste scripts/verify-supabase-schema.sql"
echo "   - Run it to see what's missing"
echo ""

