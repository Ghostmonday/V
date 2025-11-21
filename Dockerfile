# Multi‑stage Dockerfile optimized for Railway
## ---------- Build stage ----------
FROM node:20-alpine AS builder
WORKDIR /app

# Install only production + dev deps needed for build
COPY package*.json ./
RUN npm install

# Copy source files and build
COPY . .
RUN npm run build

## ---------- Runtime stage ----------
FROM node:20-alpine AS runtime
WORKDIR /app

# Copy only compiled output and production deps
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules

# Expose the port Railway forwards (default 3000, but respect $PORT)
ENV PORT=3000
EXPOSE $PORT

# Use the same start command as defined in package.json
CMD ["node", "dist/server/index.js"]
