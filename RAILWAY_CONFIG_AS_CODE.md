# Railway Config-as-Code

This project uses Railway's **Config-as-Code** feature to manage build and deployment settings.

## Configuration Files

We have **two** config files (Railway supports both):

1. **`railway.json`** - JSON format (currently active)
2. **`railway.toml`** - TOML format (alternative)

Railway will automatically detect and use whichever file exists. Both files contain the same configuration.

## Current Configuration

```json
{
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile"
  },
  "deploy": {
    "startCommand": "node dist/server/index.js",
    "healthcheckPath": "/health",
    "healthcheckTimeout": 100,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

## What This Configures

### Build Settings
- **Builder**: Uses Dockerfile (multi-stage build)
- **Dockerfile Path**: `Dockerfile` (root directory)

### Deploy Settings
- **Start Command**: `node dist/server/index.js`
- **Health Check Path**: `/health` endpoint
- **Health Check Timeout**: 100 seconds
- **Restart Policy**: Restart on failure (up to 10 retries)

## Environment Variables

⚠️ **Important**: Environment variables are **NOT** stored in the config file for security reasons.

Set them via:
1. **Railway Dashboard** → Variables tab
2. **Railway CLI**: `railway variables --set "KEY=VALUE"`

### Required Variables:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `JWT_SECRET`
- `NODE_ENV=production`
- `REDIS_URL` (auto-set when Redis service is added)

See `RAILWAY_ENV_SETUP.md` for complete setup instructions.

## Custom Config File Location

If your config file is not in the root directory, specify the path in Railway Dashboard:
- Service Settings → Build → Config File Path: `/path/to/railway.json`

## Benefits of Config-as-Code

✅ **Version Control**: Configuration changes are tracked in git  
✅ **Consistency**: Same config across all environments  
✅ **Reproducibility**: Easy to replicate deployments  
✅ **Collaboration**: Team can see and review config changes  

## Updating Configuration

1. Edit `railway.json` or `railway.toml`
2. Commit and push to your repository
3. Railway automatically applies the new configuration on next deploy

## Railway Documentation

- [Config-as-Code Guide](https://docs.railway.com/deploy/config-as-code)
- [Build Configuration](https://docs.railway.com/guides/build-configuration)
- [Schema Reference](https://railway.com/railway.schema.json)

## Important Notes

⚠️ **Config-as-code overrides dashboard settings**  
Settings defined in `railway.json` or `railway.toml` will **always override** values set in the Railway Dashboard. The dashboard settings will not be updated with values from the config file.

✅ **Both formats are equivalent**  
Railway treats `railway.json` and `railway.toml` identically. Use whichever format you prefer.

🔍 **View config source in deployments**  
On a deployment's details page, settings from config files show a file icon. Hover over it to see which part of the file the value came from.

