#!/bin/bash
# Swift syntax validation script for VibeZ iOS
# Run from repository root: ./scripts/dev/ios/validate_swift.sh

# Get script directory and navigate to iOS directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IOS_DIR="$REPO_ROOT/frontend/iOS"

cd "$IOS_DIR"

echo "=== VibeZ iOS Swift Syntax Validation ==="
echo "📁 Working directory: $(pwd)"
echo ""

ERRORS=0
FILES_CHECKED=0

# Check each Swift file
for file in $(find . -name "*.swift" -type f | grep -v ".build" | sort); do
    FILES_CHECKED=$((FILES_CHECKED + 1))
    echo -n "Checking $file... "
    
    # Basic syntax check using swiftc (will fail without full project, but catches obvious errors)
    if swiftc -parse "$file" 2>&1 | grep -q "error:"; then
        echo "❌ ERRORS FOUND"
        swiftc -parse "$file" 2>&1 | grep "error:"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ OK"
    fi
done

echo ""
echo "=== Validation Summary ==="
echo "Files checked: $FILES_CHECKED"
echo "Files with errors: $ERRORS"

if [ $ERRORS -eq 0 ]; then
    echo "✅ All files passed basic syntax validation"
    echo ""
    echo "Note: Full compilation requires an Xcode project."
    echo "See frontend/iOS/XCODE_SETUP.md for project creation instructions."
    exit 0
else
    echo "❌ Some files have syntax errors"
    exit 1
fi

