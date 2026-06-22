# syntax=docker/dockerfile:1.7

############################
# Stage 1: build (native)  #
############################
FROM node:20-bookworm AS build
WORKDIR /app

# Toolchain for better-sqlite3 native compilation.
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 make g++ ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY package.json ./
# Compile native deps now so the runtime image carries the prebuilt binding.
RUN npm install --omit=dev --no-audit --no-fund

############################
# Stage 2: runtime         #
############################
FROM node:20-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

# Runtime needs:
#  - docker CLI: to `docker exec` into the sibling wireguard container and run `wg`.
#  - wireguard-tools: not strictly required in this container (wg runs inside the
#    wireguard container) but handy for diagnostics.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates docker.io \
    && rm -rf /var/lib/apt/lists/*

# Bring in the compiled node_modules (prebuilt better-sqlite3 .node) + source.
COPY --from=build /app/node_modules ./node_modules
COPY . .

# /data is a mounted volume (SQLite WAL); declare it for clarity.
VOLUME ["/data"]
EXPOSE 3200

# Healthcheck hits the public /health.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:'+(process.env.PORT||3200)+'/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "server.js"]
