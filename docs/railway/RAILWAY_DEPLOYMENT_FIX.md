# Railway Deployment Fix

## Problem Identified

Your Railway deployment was failing with the error:
```
npm error enoent Could not read package.json: Error: ENOENT: no such file or directory, open '/app/package.json'
```

## Root Causes

1. **`.dockerignore` was excluding `dist` folder** - This prevented the built files from being included in the Docker image
2. **`railway.json` had wrong start command** - It was using `npm start` which requires `package.json` to exist, but Railway might not respect the Dockerfile properly
3. **Dockerfile wasn't handling monorepo workspace structure properly** - Missing workspace package.json files caused npm install to fail

## Fixes Applied

### 1. Updated `.dockerignore`
- ✅ Removed `dist` from ignored files
- ✅ Added `.turbo`, `.next`, and other build artifacts that should be excluded from the build context

### 2. Updated `Dockerfile`
- ✅ Added explicit copying of all workspace `package.json` files before `npm install`
- ✅ Added health check for better container monitoring
- ✅ Set `NODE_ENV=production` explicitly
- ✅ Improved multi-stage build to ensure all necessary files are copied to runtime

### 3. Updated `railway.json`
- ✅ Changed `startCommand` from `npm start` to `node dist/server/index.js`
- ✅ This ensures the start command works even if Railway doesn't use the Dockerfile CMD

## How to Deploy

### Option 1: Push to Git (Recommended)
```bash
git add .dockerignore Dockerfile railway.json
git commit -m "fix: Railway deployment configuration for monorepo"
git push
```

Railway will automatically detect the changes and rebuild.

### Option 2: Manual Railway CLI Deploy
```bash
railway up
```

### Option 3: Force Redeploy in Railway Dashboard
1. Go to your Railway project
2. Click on your service
3. Go to "Deployments" tab
4. Click "Redeploy" on the latest deployment

## Verification Steps

Once deployed, check these:

1. **Build logs should show:**
   ```
   ✓ Building with Dockerfile
   ✓ npm install completes successfully
   ✓ npm run build completes successfully
   ✓ dist/ directory is created
   ```

2. **Runtime logs should show:**
   ```
   Starting Container
   Server listening on port 3000 (or your configured PORT)
   ```

3. **Health check should return 200:**
   ```bash
   curl https://your-app.railway.app/health
   ```

## If It Still Fails

### Check Railway Settings

1. **Verify Builder is set to Dockerfile:**
   - Go to Railway Dashboard → Settings → Builder
   - Ensure "Dockerfile" is selected (not Nixpacks)

2. **Check Environment Variables:**
   Make sure these are set:
   - `NODE_ENV=production`
   - `PORT=3000` (or Railway's default)
   - All required database URLs, API keys, etc.

3. **Check Build Command:**
   - Should be empty (Dockerfile handles it)
   - Or set to: `docker build -t app .`

4. **Check Start Command:**
   - Should be: `node dist/server/index.js`
   - Or leave empty to use Dockerfile CMD

### Alternative: Use Nixpacks

If you prefer Nixpacks over Docker:

1. Remove or rename `Dockerfile` temporarily
2. Ensure `nixpacks.toml` is present (already configured)
3. Railway will auto-detect and use Nixpacks
4. The `nixpacks.toml` is already correctly configured:
   ```toml
   [start]
   cmd = "npm start"
   ```

### Debug Build Issues

If build fails, check these in Railway logs:

```bash
# Look for these patterns:
- "npm ERR!" - npm installation failed
- "error TS" - TypeScript compilation failed
- "Cannot find module" - Missing dependencies
- "ENOENT" - File not found
```

## Testing Locally

Before deploying, test the Docker build locally:

```bash
# Build the image
docker build -t vibez-app .

# Run the container
docker run -p 3000:3000 \
  -e NODE_ENV=production \
  -e DATABASE_URL=your_db_url \
  vibez-app

# Test the health endpoint
curl http://localhost:3000/health
```

## Additional Notes

### Monorepo Considerations

This is a Turborepo monorepo with workspaces:
- `apps/api/` - Main API application
- `packages/ai-mod/` - AI moderation package
- `packages/core/` - Core utilities
- `packages/supabase/` - Supabase client

The Dockerfile now correctly handles all workspace dependencies.

### Build Performance

The multi-stage Dockerfile:
- **Build stage**: ~2-3 minutes (includes npm install + build)
- **Runtime stage**: Minimal - only copies compiled code
- **Final image size**: ~150-200MB (optimized Alpine Linux)

### Rollback Plan

If the deployment fails and you need to rollback:

```bash
# Revert the changes
git revert HEAD

# Or reset to previous commit
git reset --hard HEAD~1
git push --force
```

## Success Indicators

You'll know the deployment succeeded when you see:

1. ✅ Build completes without errors
2. ✅ Container starts and stays running (no restart loops)
3. ✅ Health check returns 200 OK
4. ✅ Application logs show normal startup messages
5. ✅ No `ENOENT` errors in logs

## Support

If you continue to have issues:

1. Share the full Railway build logs
2. Share the runtime logs (first 50 lines after container starts)
3. Confirm your Railway service settings (Builder, Root Directory, etc.)

