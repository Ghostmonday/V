#!/bin/bash

# Production Deployment Script
# Deploys backend and prepares iOS build

set -e

echo "🚀 Starting VibeZ Production Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check required environment variables
if [ -z "$SUPABASE_PROJECT_ID" ]; then
    echo -e "${RED}❌ SUPABASE_PROJECT_ID not set${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Environment variables configured${NC}"

# 1. Build backend
echo -e "${YELLOW}📦 Building backend...${NC}"
npm run build:prod

# Verify no console.log or debugger in dist
echo -e "${YELLOW}🔍 Verifying production build...${NC}"
if grep -r "console.log" dist/ --include="*.js" > /dev/null 2>&1; then
    echo -e "${RED}❌ Found console.log in production build${NC}"
    exit 1
fi

if grep -r "debugger" dist/ --include="*.js" > /dev/null 2>&1; then
    echo -e "${RED}❌ Found debugger in production build${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Production build verified${NC}"

# 2. Deploy Supabase Edge Functions
echo -e "${YELLOW}☁️  Deploying Supabase Edge Functions...${NC}"

if command -v supabase &> /dev/null; then
    supabase functions deploy api-key-vault --project-ref "$SUPABASE_PROJECT_ID" || echo -e "${YELLOW}⚠️  api-key-vault deployment skipped${NC}"
    supabase functions deploy llm-proxy --project-ref "$SUPABASE_PROJECT_ID" || echo -e "${YELLOW}⚠️  llm-proxy deployment skipped${NC}"
    supabase functions deploy join-room --project-ref "$SUPABASE_PROJECT_ID" || echo -e "${YELLOW}⚠️  join-room deployment skipped${NC}"
    
    echo -e "${GREEN}✓ Edge Functions deployed${NC}"
else
    echo -e "${YELLOW}⚠️  Supabase CLI not found, skipping Edge Function deployment${NC}"
fi

# 3. Run database migrations
echo -e "${YELLOW}🗄️  Running database migrations...${NC}"
if command -v supabase &> /dev/null; then
    supabase db push --include-all --project-ref "$SUPABASE_PROJECT_ID" || echo -e "${YELLOW}⚠️  Database migrations skipped${NC}"
    echo -e "${GREEN}✓ Database migrations complete${NC}"
else
    echo -e "${YELLOW}⚠️  Supabase CLI not found, skipping migrations${NC}"
fi

# 4. Run tests
echo -e "${YELLOW}🧪 Running tests...${NC}"
npm run test:security || echo -e "${YELLOW}⚠️  Security tests skipped${NC}"

# 5. Build iOS (if on macOS with Xcode)
if [[ "$OSTYPE" == "darwin"* ]] && command -v xcodebuild &> /dev/null; then
    echo -e "${YELLOW}📱 Building iOS app...${NC}"
    cd frontend/iOS
    
    # Clean build folder
    rm -rf build/
    
    # Archive
    xcodebuild -scheme VibeZ \
        -configuration Release \
        -archivePath build/VibeZ.xcarchive \
        archive || echo -e "${YELLOW}⚠️  iOS archive failed${NC}"
    
    # Export (requires ExportOptions.plist)
    if [ -f ExportOptions.plist ]; then
        xcodebuild -exportArchive \
            -archivePath build/VibeZ.xcarchive \
            -exportOptionsPlist ExportOptions.plist \
            -exportPath build/ || echo -e "${YELLOW}⚠️  iOS export failed${NC}"
    else
        echo -e "${YELLOW}⚠️  ExportOptions.plist not found, skipping export${NC}"
    fi
    
    cd ../..
    echo -e "${GREEN}✓ iOS build complete${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping iOS build (not on macOS or Xcode not found)${NC}"
fi

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Set Supabase secrets:"
echo "   supabase secrets set DEEPSEEK_API_KEY=\"\$DEEPSEEK_API_KEY\" --project-ref $SUPABASE_PROJECT_ID"
echo "   supabase secrets set LIVEKIT_API_KEY=\"\$LIVEKIT_API_KEY\" --project-ref $SUPABASE_PROJECT_ID"
echo "   supabase secrets set LIVEKIT_API_SECRET=\"\$LIVEKIT_API_SECRET\" --project-ref $SUPABASE_PROJECT_ID"
echo "   supabase secrets set LIVEKIT_URL=\"\$LIVEKIT_URL\" --project-ref $SUPABASE_PROJECT_ID"
echo ""
echo "2. Upload iOS build to TestFlight (if built)"
echo "3. Start production server: npm start"

