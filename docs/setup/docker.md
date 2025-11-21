# Docker Setup for Validation

## Installation Status

Docker Desktop installation requires admin privileges. Here are your options:

## Option 1: Manual Installation (Recommended)

1. **Download Docker Desktop:**
   - Visit: https://www.docker.com/products/docker-desktop
   - Download for Mac (Apple Silicon or Intel)
   - Open the `.dmg` file and drag Docker to Applications

2. **Start Docker Desktop:**
   - Open `/Applications/Docker.app`
   - Wait for Docker to start (whale icon appears in menu bar)
   - Docker is ready when the menu bar icon is steady (not animating)

3. **Verify Installation:**
   ```bash
   docker --version
   docker compose version
   ```

## Option 2: Homebrew Installation (Requires Password)

If you prefer command-line installation:

```bash
brew install --cask docker
```

Then start Docker Desktop:

```bash
open -a Docker
```

## After Docker is Running

Once Docker Desktop is running, execute:

```bash
npm run validate:docker:full
```

This will:

1. Start PostgreSQL and Redis containers
2. Initialize the database schema
3. Run all Phase 1-3 validations
4. Show results (target: 20/20 tests passing)

## Quick Commands

```bash
# Start validation containers
npm run validate:docker:up

# Setup database
npm run validate:docker:setup

# Run validations
npm run validate:docker:run

# Stop containers
npm run validate:docker:down

# Full validation (all-in-one)
npm run validate:docker:full
```

## Troubleshooting

### Docker not starting

- Check Docker Desktop is running (whale icon in menu bar)
- Restart Docker Desktop if needed
- Check system requirements: https://docs.docker.com/desktop/install/mac-install/

### Port conflicts

- If ports 5433 or 6380 are in use, edit `docker-compose.validation.yml`
- Change ports in the `ports:` section

### Permission errors

- Ensure Docker Desktop has necessary permissions
- Check System Preferences > Security & Privacy

## Next Steps

1. Install Docker Desktop (if not already installed)
2. Start Docker Desktop
3. Run: `npm run validate:docker:full`
4. Review validation results
