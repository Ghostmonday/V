#!/bin/bash
# VibeZ Full Stack Security Audit
# Comprehensive security scan for main branch

set -e

echo "🔒 VibeZ Security Audit - Full Stack Scan"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ISSUES_FOUND=0

# 1. Check for hardcoded secrets
echo "🔍 Scanning for hardcoded secrets..."
SECRETS=$(grep -r -i -E "(api[_-]?key|secret|password|token|private[_-]?key|aws[_-]?access|AKIA)[\s]*[:=][\s]*['\"][^'\"]{8,}" \
    --include="*.ts" \
    --include="*.tsx" \
    --include="*.js" \
    --include="*.swift" \
    --exclude-dir=node_modules \
    --exclude-dir=.git \
    --exclude-dir=dist \
    --exclude-dir=build \
    . 2>/dev/null || true)

if [ -n "$SECRETS" ]; then
    echo -e "${RED}❌ Potential hardcoded secrets found:${NC}"
    echo "$SECRETS"
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No hardcoded secrets detected${NC}"
fi
echo ""

# 2. Check for exposed .env files
echo "🔍 Checking for exposed environment files..."
ENV_FILES=$(find . -name ".env" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null || true)
if [ -n "$ENV_FILES" ]; then
    echo -e "${RED}❌ .env files found (should not be committed):${NC}"
    echo "$ENV_FILES"
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No .env files in repository${NC}"
fi
echo ""

# 3. Check TypeScript for unsafe patterns
echo "🔍 Scanning TypeScript for unsafe patterns..."
UNSAFE_EVAL=$(grep -r "eval(" --include="*.ts" --include="*.tsx" --exclude-dir=node_modules . 2>/dev/null || true)
if [ -n "$UNSAFE_EVAL" ]; then
    echo -e "${YELLOW}⚠️  eval() usage found (code injection risk):${NC}"
    echo "$UNSAFE_EVAL" | head -10
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No eval() usage${NC}"
fi
echo ""

# 4. Check for SQL injection risks
echo "🔍 Checking for SQL injection risks..."
SQL_CONCAT=$(grep -r -E "SELECT.*\+.*\$\{|INSERT.*\+.*\$\{|UPDATE.*\+.*\$\{" --include="*.ts" --exclude-dir=node_modules . 2>/dev/null || true)
if [ -n "$SQL_CONCAT" ]; then
    echo -e "${RED}❌ Potential SQL injection via string concatenation:${NC}"
    echo "$SQL_CONCAT" | head -10
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No obvious SQL injection patterns${NC}"
fi
echo ""

# 5. Check for weak crypto
echo "🔍 Scanning for weak cryptography..."
WEAK_CRYPTO=$(grep -r -E "(MD5|SHA1|DES|RC4)" --include="*.ts" --include="*.swift" --exclude-dir=node_modules . 2>/dev/null || true)
if [ -n "$WEAK_CRYPTO" ]; then
    echo -e "${YELLOW}⚠️  Weak crypto algorithms detected:${NC}"
    echo "$WEAK_CRYPTO" | grep -v "SHA256" | grep -v "comment" | head -10
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No weak crypto algorithms${NC}"
fi
echo ""

# 6. Check iOS entitlements
echo "🔍 Checking iOS entitlements and Info.plist..."
if [ -f "frontend/iOS/Info.plist" ]; then
    # Check for excessive permissions
    PERMISSIONS=$(grep -i "NSCamera\|NSMicrophone\|NSLocation\|NSPhoto\|NSContacts" frontend/iOS/Info.plist 2>/dev/null || true)
    if [ -n "$PERMISSIONS" ]; then
        echo -e "${YELLOW}⚠️  iOS permissions requested:${NC}"
        echo "$PERMISSIONS"
    else
        echo -e "${GREEN}✅ Minimal iOS permissions${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No Info.plist found${NC}"
fi
echo ""

# 7. Check for console.log in production
echo "🔍 Checking for debug statements in production code..."
CONSOLE_LOGS=$(grep -r "console\\.log\|console\\.debug\|debugger" --include="*.ts" --include="*.tsx" --exclude-dir=node_modules src/ 2>/dev/null | wc -l)
if [ "$CONSOLE_LOGS" -gt 50 ]; then
    echo -e "${YELLOW}⚠️  $CONSOLE_LOGS console.log statements found${NC}"
    echo "Consider removing debug logs in production"
else
    echo -e "${GREEN}✅ Acceptable number of debug statements ($CONSOLE_LOGS)${NC}"
fi
echo ""

# 8. Check for insecure HTTP calls
echo "🔍 Scanning for insecure HTTP calls..."
HTTP_INSECURE=$(grep -r "http://" --include="*.ts" --include="*.tsx" --include="*.swift" --exclude-dir=node_modules . 2>/dev/null | grep -v "localhost" | grep -v "127.0.0.1" | grep -v "example" | grep -v "comment" || true)
if [ -n "$HTTP_INSECURE" ]; then
    echo -e "${RED}❌ Insecure HTTP calls detected:${NC}"
    echo "$HTTP_INSECURE" | head -10
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ All external calls use HTTPS${NC}"
fi
echo ""

# 9. Check CORS configuration
echo "🔍 Checking CORS configuration..."
CORS_ALL=$(grep -r "Access-Control-Allow-Origin.*\*" --include="*.ts" src/ 2>/dev/null || true)
if [ -n "$CORS_ALL" ]; then
    echo -e "${YELLOW}⚠️  Permissive CORS detected (allows all origins):${NC}"
    echo "$CORS_ALL"
else
    echo -e "${GREEN}✅ CORS properly configured${NC}"
fi
echo ""

# 10. Check authentication middleware usage
echo "🔍 Verifying authentication middleware coverage..."
UNPROTECTED_ROUTES=$(grep -r "router\\.post\|router\\.put\|router\\.delete" --include="*routes.ts" src/routes/ | grep -v "authMiddleware" | grep -v "supabaseAuthMiddleware" | wc -l)
if [ "$UNPROTECTED_ROUTES" -gt 5 ]; then
    echo -e "${YELLOW}⚠️  $UNPROTECTED_ROUTES potentially unprotected routes${NC}"
    echo "Review routes to ensure proper authentication"
else
    echo -e "${GREEN}✅ Most routes protected with auth middleware${NC}"
fi
echo ""

# 11. Check for sensitive data in logs
echo "🔍 Checking for sensitive data logging..."
SENSITIVE_LOGS=$(grep -r "logInfo\|logError\|console.log" --include="*.ts" src/ | grep -i -E "(password|token|secret|key)" | grep -v "// " | wc -l)
if [ "$SENSITIVE_LOGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  $SENSITIVE_LOGS potential sensitive data logging instances${NC}"
    echo "Review logs to ensure no passwords/tokens are logged"
else
    echo -e "${GREEN}✅ No obvious sensitive data in logs${NC}"
fi
echo ""

# 12. Check package.json for known vulnerable versions
echo "🔍 Checking package.json for known issues..."
if [ -f "package.json" ]; then
    # Check for old versions of critical packages
    OLD_EXPRESS=$(grep "\"express\"" package.json | grep -E "\"4\.[0-9]\." || true)
    if [ -n "$OLD_EXPRESS" ]; then
        echo -e "${YELLOW}⚠️  Express version should be reviewed${NC}"
    fi
    
    # Check for ws (WebSocket) version
    WS_VERSION=$(grep "\"ws\"" package.json | grep -E "\"[0-7]\." || true)
    if [ -n "$WS_VERSION" ]; then
        echo -e "${YELLOW}⚠️  WebSocket library version should be updated${NC}"
    fi
    
    echo -e "${GREEN}✅ Package.json checked${NC}"
fi
echo ""

# 13. Check Swift code for security issues
echo "🔍 Scanning Swift code for security issues..."
if [ -d "frontend/iOS" ]; then
    # Check for weak random number generation
    WEAK_RANDOM=$(grep -r "arc4random\|rand()" --include="*.swift" frontend/iOS/ 2>/dev/null || true)
    if [ -n "$WEAK_RANDOM" ]; then
        echo -e "${YELLOW}⚠️  Weak random number generation in Swift:${NC}"
        echo "$WEAK_RANDOM" | head -5
    fi
    
    # Check for UserDefaults storing sensitive data
    USERDEFAULTS_SENSITIVE=$(grep -r "UserDefaults.*password\|UserDefaults.*token\|UserDefaults.*secret" --include="*.swift" frontend/iOS/ 2>/dev/null || true)
    if [ -n "$USERDEFAULTS_SENSITIVE" ]; then
        echo -e "${RED}❌ Sensitive data in UserDefaults (should use Keychain):${NC}"
        echo "$USERDEFAULTS_SENSITIVE"
        ((ISSUES_FOUND++))
    else
        echo -e "${GREEN}✅ No sensitive data in UserDefaults${NC}"
    fi
fi
echo ""

# 14. Check for test credentials in code
echo "🔍 Checking for test credentials..."
TEST_CREDS=$(grep -r -i -E "(test_key|demo_password|admin123|password123)" --include="*.ts" --include="*.swift" --exclude-dir=node_modules --exclude-dir=tests --exclude-dir=__tests__ . 2>/dev/null || true)
if [ -n "$TEST_CREDS" ]; then
    echo -e "${YELLOW}⚠️  Test credentials found:${NC}"
    echo "$TEST_CREDS" | head -10
else
    echo -e "${GREEN}✅ No test credentials in code${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo "🔒 Security Audit Summary"
echo "=========================================="
if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ No critical security issues detected${NC}"
    echo ""
    echo "Clean scan. Good security posture."
    exit 0
else
    echo -e "${RED}❌ Found $ISSUES_FOUND critical issues${NC}"
    echo ""
    echo "Review and fix issues above before deployment."
    exit 1
fi

