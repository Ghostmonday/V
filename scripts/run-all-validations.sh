#!/bin/bash
# ===============================================
# Run All Phase 1-3 Validations
# ===============================================
# This script runs all validation checks for phases 1, 2, and 3

set -e

echo "🚀 Starting Phase 1-3 Complete Validation"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Node.js: $(node --version)${NC}"

# Check tsx
if ! command -v tsx &> /dev/null && ! command -v npx &> /dev/null; then
    echo -e "${RED}❌ tsx not found. Install with: npm install -g tsx${NC}"
    exit 1
fi
echo -e "${GREEN}✅ tsx available${NC}"

# Check psql
if ! command -v psql &> /dev/null; then
    echo -e "${YELLOW}⚠️  psql not found - SQL validation will be skipped${NC}"
    SKIP_SQL=true
else
    echo -e "${GREEN}✅ psql: $(psql --version | head -1)${NC}"
    SKIP_SQL=false
fi

# Check Redis
if ! command -v redis-cli &> /dev/null; then
    echo -e "${YELLOW}⚠️  redis-cli not found - Redis checks may fail${NC}"
else
    if redis-cli ping &> /dev/null; then
        echo -e "${GREEN}✅ Redis is running${NC}"
    else
        echo -e "${YELLOW}⚠️  Redis is not running - Redis checks may fail${NC}"
    fi
fi

echo ""
echo "=========================================="
echo ""

# 1. TypeScript Validation
echo -e "${GREEN}📝 Running TypeScript Validation...${NC}"
echo ""

if command -v tsx &> /dev/null; then
    tsx scripts/validate-phases-1-3.ts
elif command -v npx &> /dev/null; then
    npx tsx scripts/validate-phases-1-3.ts
else
    echo -e "${RED}❌ Cannot run TypeScript validation - tsx not available${NC}"
    exit 1
fi

TS_EXIT_CODE=$?

echo ""
echo "=========================================="
echo ""

# 2. SQL Database Validation
if [ "$SKIP_SQL" = false ]; then
    echo -e "${GREEN}🗄️  Running SQL Database Validation...${NC}"
    echo ""
    
    if [ -z "$DATABASE_URL" ]; then
        echo -e "${YELLOW}⚠️  DATABASE_URL not set${NC}"
        echo "   Set it with: export DATABASE_URL='postgresql://...'"
        echo "   Or run manually: psql \$DATABASE_URL -f sql/validate-phases-1-3.sql"
    else
        psql "$DATABASE_URL" -f sql/validate-phases-1-3.sql
        SQL_EXIT_CODE=$?
    fi
else
    echo -e "${YELLOW}⏭️  Skipping SQL validation (psql not found)${NC}"
    SQL_EXIT_CODE=0
fi

echo ""
echo "=========================================="
echo ""

# Summary
echo -e "${GREEN}📊 Validation Summary${NC}"
echo ""

if [ $TS_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ TypeScript validation: PASSED${NC}"
else
    echo -e "${RED}❌ TypeScript validation: FAILED${NC}"
fi

if [ "$SKIP_SQL" = false ] && [ -n "$DATABASE_URL" ]; then
    if [ $SQL_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✅ SQL validation: PASSED${NC}"
    else
        echo -e "${RED}❌ SQL validation: FAILED${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  SQL validation: SKIPPED${NC}"
fi

echo ""
echo "=========================================="
echo ""

# Check for results file
if [ -f "validation-results-phases-1-3.json" ]; then
    echo -e "${GREEN}📄 Detailed results saved to: validation-results-phases-1-3.json${NC}"
    echo ""
    echo "View results:"
    echo "  cat validation-results-phases-1-3.json | jq ."
fi

echo ""
echo "📚 For manual validation, see: VALIDATION_CHECKLIST.md"
echo ""

# Exit with error if any validation failed
if [ $TS_EXIT_CODE -ne 0 ] || ([ "$SKIP_SQL" = false ] && [ -n "$DATABASE_URL" ] && [ $SQL_EXIT_CODE -ne 0 ]); then
    exit 1
else
    exit 0
fi

