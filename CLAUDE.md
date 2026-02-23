# IronClaw (OpenClaw Runtime)

## Build & Deploy

- **Repo:** `omoios/ironclaw` (transferred from `kivo360/ironclaw` on 2026-02-18)
- **Docker image:** `ghcr.io/omoios/ironclaw`
- **Build system:** Depot (project `rdlhplbjgc`, Geodexes org) with OIDC auth via GitHub Actions
- **CI workflow:** `.github/workflows/build-image.yml` — triggers on push to `main`
- **Deployment:** Fly.io machines provisioned by `ironclaw-dashboard`

## Dockerfile Notes

- Single-stage build on `node:22-bookworm-slim`
- Uses `--chown=node:node` on all `COPY` instructions to avoid slow `chown -R` at the end
- Build cache mounts: pnpm store (`/pnpm/store`), apt cache
- Depot persists build cache on NVMe — no need for `buildkit-cache-dance` or GHA cache
- Final image runs as `node` user (non-root) on ports 3100 (web) and 18789 (gateway)

## Common Pitfalls

- **Never use `RUN chown -R node:node /app`** at the end of a Dockerfile with large node_modules trees. Use `COPY --chown=node:node` instead. The recursive chown can take minutes on hundreds of thousands of files.
