# Homepage - self-hosted services dashboard
# Two-stage build: Node.js build, Alpine runtime

ARG HOMEPAGE_VERSION=v1.10.1

FROM node:24-slim AS builder

ARG HOMEPAGE_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${HOMEPAGE_VERSION} \
    https://forge.ops.eblu.me/eblume/homepage.git /app

WORKDIR /app
RUN mkdir -p config \
 && corepack enable && corepack prepare pnpm@latest --activate \
 && pnpm install --frozen-lockfile \
 && NEXT_TELEMETRY_DISABLED=1 pnpm run build

FROM node:24-alpine

LABEL org.opencontainers.image.title=Homepage
LABEL org.opencontainers.image.description="A self-hosted services landing page"
LABEL org.opencontainers.image.source=https://github.com/gethomepage/homepage

WORKDIR /app

COPY --from=builder --chown=1000:1000 /app/public ./public
COPY --from=builder --chown=1000:1000 /app/.next/standalone/ ./
COPY --from=builder --chown=1000:1000 /app/.next/static/ ./.next/static

RUN mkdir -p /app/config && chown 1000:1000 /app/config

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=20s \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/api/healthcheck || exit 1

USER 1000
CMD ["node", "server.js"]
