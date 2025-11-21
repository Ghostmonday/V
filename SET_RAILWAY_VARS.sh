#!/bin/bash
# Copy-paste these commands after: railway login && railway link

railway variables --set "NEXT_PUBLIC_SUPABASE_URL=https://nqkxynyplrvopjyffrgy.supabase.co"
railway variables --set "SUPABASE_SERVICE_ROLE_KEY=sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7"
railway variables --set "JWT_SECRET=4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw=="
railway variables --set "NODE_ENV=production"

echo "✅ All variables set!"
echo "Next: railway add --database redis && railway up"
