# Development Dockerfile for hot-reload
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Copy source code and public files
COPY src ./src
COPY public ./public
COPY tsconfig.json ./
COPY tailwind.config.js ./
COPY postcss.config.js ./
# Install dependencies
RUN npm ci

# Expose port
EXPOSE 5000 3000

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:5000 || exit 1

# Start the development server with hot-reload
CMD ["sh", "-c", "npm start"]
