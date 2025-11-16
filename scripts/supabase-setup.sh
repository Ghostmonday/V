#!/bin/bash

# ===============================================
# Supabase Database Setup Script
# ===============================================
# This script helps set up the VibeZ database schema in Supabase
# Run this after creating your Supabase project

set -e

echo "🚀 VibeZ Supabase Database Setup"
echo "===================================="
echo ""

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI is not installed."
    echo "   Install it with: npm install -g supabase"
    exit 1
fi

# Check if user is logged in
if ! supabase projects list &> /dev/null; then
    echo "❌ Not logged in to Supabase."
    echo "   Run: supabase login"
    exit 1
fi

echo "📋 This script will:"
echo "   1. Link to your Supabase project"
echo "   2. Run all SQL migrations in order"
echo "   3. Verify the schema"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPO_REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Get project reference
echo ""
read -p "Enter your Supabase project reference ID: " PROJECT_REF

if [ -z "$PROJECT_REF" ]; then
    echo "❌ Project reference is required"
    exit 1
fi

# Link to project
echo ""
echo "🔗 Linking to Supabase project..."
supabase link --project-ref "$PROJECT_REF"

# Run migrations in order
echo ""
echo "📦 Running migrations..."

MIGRATIONS=(
    "sql/01_sinapse_schema.sql"
    "sql/02_compressor_functions.sql"
    "sql/03_retention_policy.sql"
    "sql/04_moderation_apply.sql"
    "sql/05_rls_policies.sql"
    "sql/06_partition_management.sql"
    "sql/07_healing_logs.sql"
    "sql/08_enhanced_rls_policies.sql"
    "sql/09_p0_features.sql"
    "sql/10_integrated_features.sql"
)

for migration in "${MIGRATIONS[@]}"; do
    if [ -f "$migration" ]; then
        echo "  → Running $migration..."
        supabase db push --file "$migration" || {
            echo "❌ Failed to run $migration"
            exit 1
        }
    else
        echo "  ⚠️  Skipping $migration (file not found)"
    fi
done

echo ""
echo "✅ Migrations completed!"
echo ""
echo "🔍 Verifying schema..."

# Run verification script if it exists
if [ -f "sql/migrations/verify-supabase-schema.sql" ]; then
    supabase db push --file "sql/migrations/verify-supabase-schema.sql"
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Set up Row Level Security (RLS) policies in Supabase dashboard"
echo "   2. Configure environment variables in your .env file"
echo "   3. Test the API endpoints"
echo ""

