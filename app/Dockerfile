# syntax=docker/dockerfile:1.7
# ---------------------------------------------------------------------------
# Dockerfile multi-stage para tasks-api
#   1. deps    -> dependencias de producción (capa cacheable)
#   2. test    -> instala devDependencies, corre lint + tests (falla el build si fallan)
#   3. runtime -> imagen final mínima: alpine, usuario no-root, sin npm/devDeps
# ---------------------------------------------------------------------------
ARG NODE_VERSION=22-alpine

# ---------- 1) dependencias de producción ----------
FROM node:${NODE_VERSION} AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev --ignore-scripts

# ---------- 2) test (lint + unit tests) ----------
FROM node:${NODE_VERSION} AS test
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --ignore-scripts
COPY . .
RUN npm run lint && npm test

# ---------- 3) runtime ----------
FROM node:${NODE_VERSION} AS runtime
ARG APP_VERSION=dev
ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION}

LABEL org.opencontainers.image.title="tasks-api" \
      org.opencontainers.image.description="API de tareas - Proyecto Final DevOps" \
      org.opencontainers.image.version="${APP_VERSION}"

# Quita npm/yarn/corepack de la imagen final: menos superficie de ataque y menos CVEs.
RUN apk upgrade --no-cache \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx \
           /usr/local/lib/node_modules/corepack /usr/local/bin/corepack /opt/yarn* \
           /usr/local/bin/yarn /usr/local/bin/yarnpkg

WORKDIR /app
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/healthz || exit 1

CMD ["node", "src/server.js"]
