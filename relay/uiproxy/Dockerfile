# syntax=docker/dockerfile:1.7
FROM node:20-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY server.js ./
EXPOSE 8090
# No deps (stdlib http+crypto). Healthcheck hits the deny-path (401 = alive).
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:'+(process.env.UIPROXY_PORT||8090)+'/',r=>process.exit(r.statusCode?0:1)).on('error',()=>process.exit(1))"
CMD ["node", "server.js"]
