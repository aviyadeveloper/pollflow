# Build stage
FROM node:22-alpine AS builder

# Upgrade npm to 11.15.0+ for security features (minimum-release-age, allow-git)
RUN npm install -g npm@latest

WORKDIR /app

# Copy package configuration files
COPY .npmrc ./.npmrc
COPY package-lock.json ./package-lock.json
COPY package.json ./package.json

# Install dependencies (npm ci uses exact lockfile versions)
RUN npm ci

# Copy source code
COPY src ./src
COPY svelte.config.js ./svelte.config.js
COPY tsconfig.json ./tsconfig.json
COPY vite.config.ts ./vite.config.ts

# Build the application (no env vars needed - connections are lazy)
RUN npm run build

# Production stage
FROM node:22-alpine

# Upgrade npm to 11.15.0+ for security features
RUN npm install -g npm@latest

WORKDIR /app

# Copy npm configuration and package files
COPY .npmrc ./.npmrc
COPY package-lock.json ./package-lock.json
COPY package.json ./

# Install production dependencies only
RUN npm ci --omit=dev

# Copy built application from builder
COPY --from=builder /app/build ./build

# Expose port
EXPOSE 3000

# Health check
# Note: Healthcheck uses hardcoded port 3000. If PORT changes, update this.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the application
# APP_ENV and PORT must be set at runtime via docker-compose or k8s
CMD ["node", "build"]
