#!/bin/bash
# VibeZ Markdown Documentation Audit & Restructure
# Scans all .md files, categorizes, fact-checks, and restructures

set -e

echo "📚 VibeZ Documentation Audit"
echo "=============================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEEPERS=()
DELETERS=()
FIXERS=()

# Function to check if file is referenced in code
check_referenced() {
    local file="$1"
    local basename=$(basename "$file" .md)
    # Check for references in code
    grep -r "$basename\|$(basename "$file")" --include="*.ts" --include="*.tsx" --include="*.swift" --include="*.sh" src/ frontend/ scripts/ 2>/dev/null | grep -v ".md:" | wc -l
}

# Function to check for outdated env vars
check_env_vars() {
    local file="$1"
    # Check for common outdated patterns
    grep -i "FIREBASE\|OLD_ENV\|DEPRECATED" "$file" 2>/dev/null | wc -l
}

# Function to check for dead links
check_links() {
    local file="$1"
    # Extract markdown links
    grep -oE '\[.*\]\([^)]+\)' "$file" 2>/dev/null | sed 's/.*(\(.*\))/\1/' | while read link; do
        # Skip external URLs
        if [[ "$link" =~ ^https?:// ]]; then
            continue
        fi
        # Check if file exists
        if [ ! -f "$(dirname "$file")/$link" ] && [ ! -f "$link" ]; then
            echo "DEAD_LINK:$link"
        fi
    done
}

# Audit each file
audit_file() {
    local file="$1"
    local category="$2"
    local reason="$3"
    
    echo -n "  📄 $(basename "$file"): "
    
    # Check if it's a completion summary (likely historical)
    if [[ "$file" =~ (COMPLETE|SUMMARY|PHASE[0-9]|AUDIT_REPORT|CLEANUP|GRADE) ]]; then
        echo -e "${RED}DELETE${NC} (historical/completion doc)"
        DELETERS+=("$file|historical")
        return
    fi
    
    # Check if referenced in code
    local refs=$(check_referenced "$file")
    
    # Check for outdated content
    local outdated=$(check_env_vars "$file")
    local dead_links=$(check_links "$file" | wc -l)
    
    # Decision logic
    if [ "$refs" -gt 0 ]; then
        echo -e "${GREEN}KEEP${NC} (referenced in code)"
        KEEPERS+=("$file|referenced")
        if [ "$outdated" -gt 0 ] || [ "$dead_links" -gt 0 ]; then
            FIXERS+=("$file|needs_fix")
        fi
    elif [[ "$file" =~ (README|SETUP|GUIDE|QUICK_START|SELF_HOSTING|iOS_RUNTIME|VALIDATION_QUICK_START|handover) ]]; then
        echo -e "${GREEN}KEEP${NC} (setup/guide doc)"
        KEEPERS+=("$file|guide")
        if [ "$outdated" -gt 0 ] || [ "$dead_links" -gt 0 ]; then
            FIXERS+=("$file|needs_fix")
        fi
    elif [[ "$file" =~ (SECURITY|RLS|PRIVACY) ]]; then
        echo -e "${GREEN}KEEP${NC} (security doc)"
        KEEPERS+=("$file|security")
    elif [[ "$file" =~ (SQL_MASTER|SUPABASE_SQL) ]]; then
        echo -e "${GREEN}KEEP${NC} (SQL reference)"
        KEEPERS+=("$file|sql")
    else
        echo -e "${YELLOW}REVIEW${NC} (needs manual check)"
        KEEPERS+=("$file|review")
    fi
}

# Main audit
echo "🔍 Scanning markdown files..."
echo ""

# Root level files
echo -e "${BLUE}Root Level Files:${NC}"
for file in *.md; do
    if [ -f "$file" ]; then
        audit_file "$file" "root" ""
    fi
done
echo ""

# Docs directory
echo -e "${BLUE}docs/ Directory:${NC}"
find docs -name "*.md" -type f | while read file; do
    audit_file "$file" "docs" ""
done
echo ""

# SQL directory
echo -e "${BLUE}sql/ Directory:${NC}"
find sql -name "*.md" -type f | while read file; do
    audit_file "$file" "sql" ""
done
echo ""

# Other locations
echo -e "${BLUE}Other Locations:${NC}"
find . -name "*.md" -type f -not -path "./docs/*" -not -path "./sql/*" -not -path "./node_modules/*" -not -path "./.git/*" -not -path "./*.md" | while read file; do
    audit_file "$file" "other" ""
done
echo ""

# Summary
echo "=============================="
echo "📊 Audit Summary"
echo "=============================="
echo -e "${GREEN}Keepers: ${#KEEPERS[@]}${NC}"
echo -e "${RED}Deleters: ${#DELETERS[@]}${NC}"
echo -e "${YELLOW}Needs Fix: ${#FIXERS[@]}${NC}"
echo ""

# Output detailed lists
echo "KEEPERS:" > /tmp/md_audit_keepers.txt
printf '%s\n' "${KEEPERS[@]}" >> /tmp/md_audit_keepers.txt

echo "DELETERS:" > /tmp/md_audit_deleters.txt
printf '%s\n' "${DELETERS[@]}" >> /tmp/md_audit_deleters.txt

echo "FIXERS:" > /tmp/md_audit_fixers.txt
printf '%s\n' "${FIXERS[@]}" >> /tmp/md_audit_fixers.txt

echo "✅ Audit complete. Results saved to /tmp/md_audit_*.txt"

