#!/bin/bash
# VibeZ Backend Setup Script

set -e

echo "🚀 VibeZ Backend Setup"
echo "========================"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed."
    echo "Please install Node.js first:"
    echo "  brew install node"
    echo "  or visit https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js version: $(node --version)"
echo "✅ npm version: $(npm --version)"
echo ""

# Check .env file
if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Creating from template..."
    cp .env.example .env 2>/dev/null || {
        echo "Please create .env file with your Supabase credentials"
        exit 1
    }
fi

# Check if password placeholder exists
if grep -q "<YOUR_PASSWORD>" .env; then
    echo "⚠️  WARNING: .env file contains password placeholder."
    echo "Please update DB_URL in .env with your actual Supabase password"
    echo ""
    read -p "Press Enter to continue anyway, or Ctrl+C to exit and update .env first..."
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully"
else
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Update .env with your Supabase password"
echo "2. Run: node server.js"
echo "3. Test: curl http://localhost:3000/health"
echo ""

