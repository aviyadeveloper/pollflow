# Build stage
FROM node:22-alpine AS builder

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Build arguments for environment variables needed during build
ARG POSTGRES_HOST
ARG POSTGRES_PORT
ARG POSTGRES_DB
ARG POSTGRES_USER
ARG POSTGRES_PASSWORD
ARG REDIS_HOST
ARG REDIS_PORT
ARG REDIS_PASSWORD

# Copy package configuration files
COPY pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY pnpm-lock.yaml ./pnpm-lock.yaml
COPY package.json ./package.json

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY src ./src
COPY svelte.config.js ./svelte.config.js
COPY tsconfig.json ./tsconfig.json
COPY vite.config.ts ./vite.config.ts

# Set environment variables from build args (required by SvelteKit SSR analysis)
ENV POSTGRES_HOST=${POSTGRES_HOST}
ENV POSTGRES_PORT=${POSTGRES_PORT}
ENV POSTGRES_DB=${POSTGRES_DB}
ENV POSTGRES_USER=${POSTGRES_USER}
ENV POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
ENV REDIS_HOST=${REDIS_HOST}
ENV REDIS_PORT=${REDIS_PORT}
ENV REDIS_PASSWORD=${REDIS_PASSWORD}

# Build the application
RUN pnpm run build

# Production stage
FROM node:22-alpine

# Install pnpm for production dependencies
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy workspace configuration and package files
COPY pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY pnpm-lock.yaml ./pnpm-lock.yaml
COPY package.json ./

# Install production dependencies only
RUN pnpm install --prod --frozen-lockfile

# Copy built application from builder
COPY --from=builder /app/build ./build

# Expose port
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the application
CMD ["node", "build"]
