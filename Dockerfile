# Multi‑stage Dockerfile optimized for Railway
## ---------- Build stage ----------
FROM node:20-alpine AS builder
WORKDIR /app

# Copy package files for the root and all workspaces
COPY package*.json ./
COPY turbo.json ./
COPY tsconfig*.json ./

# Copy workspace package.json files (ensure npm can resolve workspace structure)
COPY apps/api/package.json ./apps/api/
COPY packages/ai-mod/package.json ./packages/ai-mod/
COPY packages/core/package.json ./packages/core/
COPY packages/supabase/package.json ./packages/supabase/

# Install all dependencies (including devDependencies needed for build)
RUN npm install

# Copy all source code
COPY . .

# Build the project
RUN npm run build

## ---------- Runtime stage ----------
FROM node:20-alpine AS runtime
WORKDIR /app

# Set production environment
ENV NODE_ENV=production
ENV PORT=3000

# Copy package files
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json

# Copy built output
COPY --from=builder /app/dist ./dist

# Copy node_modules (includes all workspace dependencies)
COPY --from=builder /app/node_modules ./node_modules

# Expose port
EXPOSE $PORT

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD node -e "require('http').get('http://localhost:${PORT}/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the application
CMD ["node", "dist/server/index.js"]
