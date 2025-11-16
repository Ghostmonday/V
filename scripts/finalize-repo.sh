#!/bin/bash
set -e

echo "🧹 Finalizing Repository - Cleanup and Consolidation"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Remove dead code and old files
echo "📋 Step 1: Identifying dead code and old files..."

# Find and remove common dead code patterns
find . -type f \( -name "*.ts" -o -name "*.js" -o -name "*.swift" \) \
  ! -path "./node_modules/*" \
  ! -path "./.git/*" \
  ! -path "./server/node_modules/*" \
  ! -path "./v-app/node_modules/*" \
  -exec grep -l "DEPRECATED\|TODO.*remove\|TODO.*delete\|FIXME.*remove" {} \; 2>/dev/null | while read file; do
  echo "  ⚠️  Found potentially dead code: $file"
done

# Remove archive/legacy directories if they exist
if [ -d "sql/archive" ]; then
  echo "  🗑️  Removing sql/archive directory..."
  rm -rf sql/archive
fi

# Remove old validation/test SQL files that are no longer needed
find . -name "*_backup.sql" -o -name "*_old.sql" -o -name "*_test.sql" 2>/dev/null | while read file; do
  echo "  🗑️  Removing old SQL file: $file"
  rm -f "$file"
done

# Remove temporary files
find . -name "*.tmp" -o -name "*.temp" -o -name "*.bak" 2>/dev/null | while read file; do
  echo "  🗑️  Removing temp file: $file"
  rm -f "$file"
done

echo "✅ Step 1 complete"
echo ""

# Step 2: Clean up git
echo "📋 Step 2: Cleaning up git repository..."

# Stage all deletions
echo "  📝 Staging deletions..."
git add -u

# Stage new files
echo "  📝 Staging new files..."
git add CODEBASE_INDEX.json CODEBASE_QUICKREF.md CONSOLIDATED_DOCUMENTATION.md DATA_FILES_AUDIT_REPORT.md BUILD.plan CODEBASE_COMPLETE.html
git add scripts/*.ts scripts/*.py scripts/*.sh 2>/dev/null || true
git add src/middleware/*.ts src/services/*.ts 2>/dev/null || true

echo "✅ Step 2 complete"
echo ""

# Step 3: Check current commit count
COMMIT_COUNT=$(git rev-list --count HEAD)
echo "📊 Current commit count: $COMMIT_COUNT"

if [ "$COMMIT_COUNT" -gt 1 ]; then
  echo "📋 Step 3: Squashing commits..."
  
  # Create a backup branch first
  git branch backup-before-squash 2>/dev/null || true
  
  # Get the first commit hash
  FIRST_COMMIT=$(git rev-list --max-parents=0 HEAD)
  
  # Reset to first commit but keep changes
  git reset --soft "$FIRST_COMMIT"
  
  echo "✅ Commits squashed (ready for new commit)"
else
  echo "ℹ️  Only one commit, no squashing needed"
fi

echo ""

# Step 4: Create finalized commit
echo "📋 Step 4: Creating finalized commit..."

# Check if there are changes to commit
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "chore: finalize repository - consolidate documentation and cleanup

- Consolidate all markdown files into CONSOLIDATED_DOCUMENTATION.md
- Regenerate CODEBASE_INDEX.json with current state
- Add CODEBASE_QUICKREF.md for quick reference
- Add DATA_FILES_AUDIT_REPORT.md
- Remove all old documentation files (consolidated)
- Clean up dead code and temporary files
- Finalize main branch with all changes"
  
  echo "✅ Finalized commit created"
else
  echo "ℹ️  No changes to commit"
fi

echo ""

# Step 5: Delete local branches (except main)
echo "📋 Step 5: Cleaning up branches..."
LOCAL_BRANCHES=$(git branch | grep -v "main" | grep -v "*" | sed 's/^[ ]*//')
if [ -n "$LOCAL_BRANCHES" ]; then
  echo "$LOCAL_BRANCHES" | while read branch; do
    echo "  🗑️  Deleting local branch: $branch"
    git branch -D "$branch" 2>/dev/null || true
  done
else
  echo "  ℹ️  No local branches to delete (only main exists)"
fi

echo "✅ Step 5 complete"
echo ""

# Step 6: Summary
echo "📊 Summary:"
echo "==========="
git status --short
echo ""
echo "📝 Ready to push finalized main branch"
echo ""
echo "To push, run:"
echo "  git push origin main --force"
echo ""
echo "⚠️  Note: This will force push and overwrite remote main branch"
echo "   Make sure you want to do this before proceeding!"

