#!/bin/bash

# Safe Project Cleanup Script
# Removes build artifacts, node_modules, and cache files that are already in .gitignore
# All deleted content can be regenerated via npm install and build commands

set -e  # Exit on error

echo "🧹 VibeZ Project Cleanup Script"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Calculate current size
CURRENT_SIZE=$(du -sh . 2>/dev/null | cut -f1)
echo "Current project size: ${YELLOW}$CURRENT_SIZE${NC}"
echo ""

# Items to clean (all should be in .gitignore)
CLEANUP_ITEMS=(
    "node_modules/"
    "v-app/node_modules/"
    "frontend/iOS/build/"
    "v-app/.next/"
    "dist/"
    ".turbo/"
)

# Calculate space before cleanup
echo "📊 Calculating space usage..."
BEFORE_SIZE=$(du -sk . 2>/dev/null | cut -f1)

# Show what will be deleted
echo ""
echo "🗑️  Items to be removed:"
echo "------------------------"
TOTAL_TO_DELETE=0
for item in "${CLEANUP_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        SIZE=$(du -sk "$item" 2>/dev/null | cut -f1)
        SIZE_MB=$((SIZE / 1024))
        TOTAL_TO_DELETE=$((TOTAL_TO_DELETE + SIZE))
        printf "  ${YELLOW}%-30s${NC} %6d MB\n" "$item" "$SIZE_MB"
    else
        printf "  ${GREEN}%-30s${NC} (not found)\n" "$item"
    fi
done

TOTAL_MB=$((TOTAL_TO_DELETE / 1024))
echo ""
echo "Total to delete: ${YELLOW}~${TOTAL_MB} MB${NC}"
echo ""

# Safety check: Verify items are in .gitignore
echo "🔍 Safety check: Verifying items are in .gitignore..."
ALL_SAFE=true
for item in "${CLEANUP_ITEMS[@]}"; do
    # Remove trailing slash for gitignore check
    CHECK_ITEM="${item%/}"
    if git check-ignore -q "$CHECK_ITEM" 2>/dev/null || git check-ignore -q "$item" 2>/dev/null; then
        echo "  ✓ $item is ignored"
    else
        # Check if it's a pattern match
        PATTERN_MATCH=false
        if [[ "$item" == *"node_modules"* ]] && git check-ignore -q "node_modules" 2>/dev/null; then
            PATTERN_MATCH=true
        fi
        if [[ "$item" == *".next"* ]] && git check-ignore -q ".next" 2>/dev/null; then
            PATTERN_MATCH=true
        fi
        
        if [ "$PATTERN_MATCH" = true ]; then
            echo "  ✓ $item matches ignored pattern"
        else
            echo "  ${RED}⚠ WARNING: $item is NOT in .gitignore${NC}"
            ALL_SAFE=false
        fi
    fi
done

if [ "$ALL_SAFE" = false ]; then
    echo ""
    echo "${RED}❌ Safety check failed! Some items are not properly ignored.${NC}"
    echo "Please update .gitignore before proceeding."
    exit 1
fi

echo ""
echo "✅ All items are safely ignored"
echo ""

# Confirmation prompt
read -p "Proceed with cleanup? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Perform cleanup
echo ""
echo "🧹 Cleaning up..."
echo "-----------------"

for item in "${CLEANUP_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        echo -n "  Removing $item... "
        rm -rf "$item"
        echo "${GREEN}✓${NC}"
    fi
done

# Clean up TypeScript build info files (but not in node_modules since we deleted it)
echo -n "  Removing *.tsbuildinfo files... "
find . -name "*.tsbuildinfo" -not -path "./node_modules/*" -not -path "./v-app/node_modules/*" -delete 2>/dev/null || true
echo "${GREEN}✓${NC}"

# Calculate space after cleanup
AFTER_SIZE=$(du -sk . 2>/dev/null | cut -f1)
SAVED=$((BEFORE_SIZE - AFTER_SIZE))
SAVED_MB=$((SAVED / 1024))

echo ""
echo "📊 Results:"
echo "-----------"
echo "  Before:  ${BEFORE_SIZE} KB"
echo "  After:   ${AFTER_SIZE} KB"
echo "  Saved:   ${GREEN}${SAVED_MB} MB${NC}"
echo ""

FINAL_SIZE=$(du -sh . 2>/dev/null | cut -f1)
echo "Final project size: ${GREEN}$FINAL_SIZE${NC}"
echo ""

# Show restore instructions
echo "📝 To restore dependencies:"
echo "  1. npm install (root)"
echo "  2. cd v-app && npm install"
echo "  3. Build artifacts will regenerate on next build"
echo ""

echo "${GREEN}✅ Cleanup complete!${NC}"

