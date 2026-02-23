# syntax=docker/dockerfile:1

FROM node:22-bookworm-slim AS deps

ARG OPENCLAW_DOCKER_APT_PACKAGES=""

RUN --mount=type=cache,id=apt-deps,target=/var/cache/apt \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ${OPENCLAW_DOCKER_APT_PACKAGES} && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL https://bun.sh/install | bash

RUN corepack enable

ENV PNPM_HOME="/pnpm"
ENV PATH="/root/.bun/bin:$PNPM_HOME:$PATH"

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY apps/web/package.json ./apps/web/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm install --frozen-lockfile


FROM deps AS builder

COPY . .

ENV OPENCLAW_PREFER_PNPM=1

RUN pnpm build && \
    pnpm ui:build && \
    pnpm web:build && \
    pnpm web:prepack

RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    CI=true pnpm install --prod --frozen-lockfile


FROM node:22-bookworm-slim AS runtime

ARG OPENCLAW_DOCKER_APT_PACKAGES=""

RUN --mount=type=cache,id=apt-runtime,target=/var/cache/apt \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl unzip \
      python3 python3-venv python3-dev \
      git jq ripgrep sqlite3 \
      build-essential \
      openssh-client wget \
      ${OPENCLAW_DOCKER_APT_PACKAGES} && \
    rm -rf /var/lib/apt/lists/*

# Install DuckDB CLI (needed by web app to query workspace.duckdb)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then DUCKDB_ARCH="linux-amd64"; \
    elif [ "$ARCH" = "arm64" ]; then DUCKDB_ARCH="linux-arm64"; \
    else echo "Unsupported arch: $ARCH" && exit 1; fi && \
    curl -fsSL "https://github.com/duckdb/duckdb/releases/download/v1.2.1/duckdb_cli-${DUCKDB_ARCH}.zip" -o /tmp/duckdb.zip && \
    unzip /tmp/duckdb.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/duckdb && \
    rm /tmp/duckdb.zip

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

RUN corepack enable
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV NODE_ENV=production

RUN mkdir -p /app && chown node:node /app
WORKDIR /app

COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/openclaw.mjs ./openclaw.mjs
COPY --from=builder --chown=node:node /app/package.json ./package.json
COPY --from=builder --chown=node:node /app/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=builder --chown=node:node /app/apps/web/.next/standalone ./apps/web/.next/standalone
COPY --from=builder --chown=node:node /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder --chown=node:node /app/apps/web/public ./apps/web/public
COPY --from=builder --chown=node:node /app/docs ./docs
COPY --from=builder --chown=node:node /app/extensions ./extensions
COPY --from=builder --chown=node:node /app/skills ./skills
COPY --from=builder --chown=node:node /app/assets/seed ./assets/seed
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/ui ./ui
COPY --from=builder --chown=node:node /app/pnpm-lock.yaml ./pnpm-lock.yaml


# Install qmd (markdown knowledge base search with sqlite-vec)
RUN npm install -g @tobilu/qmd

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

USER node
EXPOSE 3100
EXPOSE 18789
ENTRYPOINT ["entrypoint.sh"]
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured", "--bind", "lan"]
