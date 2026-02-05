# Multi-stage build for Calendar Sync MCP Server
FROM node:20-alpine AS builder

# Install build dependencies
RUN apk add --no-cache python3 make g++

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY src/ ./src/

# Build TypeScript
RUN npm run build

# Production stage
FROM node:20-alpine

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && \
    npm cache clean --force

# Copy built application from builder
COPY --from=builder /app/dist ./dist

# Copy configuration examples
COPY config.example.json ./
COPY *.md ./

# Create directories for credentials and tokens
RUN mkdir -p /app/credentials && \
    mkdir -p /app/tokens && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port for health check (optional)
EXPOSE 3000

# Health check (optional - for future HTTP transport)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "console.log('healthy')" || exit 1

# Set environment variables
ENV NODE_ENV=production \
    TZ=Europe/Berlin

# Default command
CMD ["node", "dist/index.js"]
