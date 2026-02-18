# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim

# Install Bun (required for build scripts) + curl (for bun installer & health checks)
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y --no-install-recommends curl && \
    curl -fsSL https://bun.sh/install | bash

ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

# Configure pnpm to use a fixed store path for cache mounting
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY apps/web/package.json ./apps/web/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

COPY . .

# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1

# Single RUN to avoid intermediate layer snapshots
RUN pnpm build && \
    pnpm ui:build && \
    pnpm web:build && \
    pnpm web:prepack

ENV NODE_ENV=production

# Allow non-root user to write temp/data files at runtime
RUN chown -R node:node /app

# Security hardening: Run as non-root user
USER node

EXPOSE 3100
EXPOSE 18789

# Start gateway server bound to LAN for container platforms.
# The web UI starts on port 3100, gateway on 18789.
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured", "--bind", "lan"]
