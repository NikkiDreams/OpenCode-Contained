---
name: devcontainers
description: "Use when writing or fixing a devcontainer.json for VS Code Dev Containers, GitHub Codespaces or the devcontainer CLI — image vs Dockerfile vs Docker Compose setups, Dev Container Features and the lockfile, lifecycle commands (onCreateCommand, postCreateCommand, postStartCommand), Codespaces prebuilds and secrets, port forwarding, and prebuilt images in CI."
license: MIT
---

# Dev Containers

Make the agent write a devcontainer that builds the same way on every laptop, in Codespaces and in
CI: a pinned base, Features instead of hand-rolled installs, lifecycle commands in the right hook,
and a `devcontainer up` check before anyone opens it in an editor.

## When to Use This Skill
- Adding `.devcontainer/devcontainer.json` to a repo so new contributors get a working setup
- Running an app plus its database in a devcontainer via Docker Compose
- Making GitHub Codespaces start fast with prebuilds and recommended secrets
- Debugging "postCreateCommand failed", wrong file ownership, or tools missing from `PATH`
- Prebuilding the devcontainer image in CI and running tests inside it with the devcontainer CLI

For production Dockerfiles see `docker-best-practices`; for Compose itself see `docker-compose`;
for a personal shell setup that Codespaces can install, see `dotfiles`.

## Choose the Setup
| Setup | Use when | Key properties |
|-------|----------|----------------|
| `image` | A stock image plus Features covers everything | `image`, `features` |
| `build` | You need OS packages or files Features don't provide | `build.dockerfile`, `build.context`, `build.args`, `build.target` |
| Docker Compose | The app needs sidecars (Postgres, Redis, a queue) | `dockerComposeFile`, `service`, `runServices`, `workspaceFolder` (required) |

Start from the `mcr.microsoft.com/devcontainers/*` images (e.g. `base:ubuntu`, `typescript-node`,
`python`) and pin a major tag. Use a Feature for each tool (`node`, `python`, `docker-in-docker`,
`github-cli`) rather than `curl | sh` in `postCreateCommand`.

## Workflow
1. Create `.devcontainer/devcontainer.json`; keep a Dockerfile or `compose.yaml` next to it.
2. Add Features with major-version tags (`ghcr.io/devcontainers/features/node:1`) and options.
3. Put each command in the correct lifecycle hook (table below).
4. Install the CLI: `npm install -g @devcontainers/cli` (needs Python and a C/C++ toolchain for one
   native dependency).
5. Run `devcontainer up --workspace-folder .` and `devcontainer exec --workspace-folder . <test cmd>`.
6. Commit `devcontainer-lock.json` (written by default on `build`/`up` since CLI 0.87) so Feature
   versions are pinned by digest.
7. For Codespaces: set `hostRequirements`, declare `secrets`, and enable prebuilds in repo settings.

## Lifecycle Commands
| Hook | Runs | Use for |
|------|------|---------|
| `initializeCommand` | On the **host**, at create and every start | Creating a local `.env` the container mounts |
| `onCreateCommand` | Once, first in-container step | Heavy installs; runs during Codespaces prebuilds |
| `updateContentCommand` | After `onCreateCommand`, again when content changes | `npm ci`, `uv sync`; also runs in prebuilds |
| `postCreateCommand` | Once, after the container is assigned to a user | Steps needing user secrets (not in prebuilds) |
| `postStartCommand` | Every container start | Starting background services |
| `postAttachCommand` | Every time a tool attaches | Printing a welcome hint |

A string runs through a shell, an array runs without a shell, and an object runs its entries in
parallel. If one hook fails, later ones are skipped. `waitFor` (default `updateContentCommand`)
decides when the editor connects.

## Example: App + Postgres via Compose
```jsonc
// .devcontainer/devcontainer.json
{
  "name": "api",
  "dockerComposeFile": ["compose.yaml"],
  "service": "app",
  "runServices": ["app", "db"],
  "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
  "shutdownAction": "stopCompose",
  "features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "22" },
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "forwardPorts": [3000, "db:5432"],
  "portsAttributes": { "3000": { "label": "api", "onAutoForward": "notify" } },
  "containerEnv": { "DATABASE_URL": "postgres://dev:dev@db:5432/app" },
  "remoteEnv": { "GITHUB_TOKEN": "${localEnv:GITHUB_TOKEN}" },
  "updateContentCommand": "npm ci",
  "postCreateCommand": "npm run db:migrate",
  "remoteUser": "node",
  "customizations": {
    "vscode": { "extensions": ["dbaeumer.vscode-eslint"] }
  },
  "hostRequirements": { "cpus": 4, "memory": "8gb" },
  "secrets": {
    "STRIPE_TEST_KEY": { "description": "Test-mode key for local checkout flows" }
  }
}
```
```yaml
# .devcontainer/compose.yaml
services:
  app:
    image: mcr.microsoft.com/devcontainers/typescript-node:22
    volumes:
      - ../..:/workspaces:cached
    command: sleep infinity        # Compose setups don't override the command for you
  db:
    image: postgres:17
    environment: { POSTGRES_USER: dev, POSTGRES_PASSWORD: dev, POSTGRES_DB: app }
    volumes: [pgdata:/var/lib/postgresql/data]
volumes:
  pgdata:
```
`overrideCommand` defaults to `true` for image/Dockerfile setups and `false` for Compose, so the
Compose service must keep itself alive (`sleep infinity`) or the container exits.

## Prebuilt Images and CI
```bash
# Build the image (Features baked in) and push it
devcontainer build --workspace-folder . --image-name ghcr.io/acme/api-devcontainer:latest --push

# Run tests inside the same environment developers use
devcontainer up --workspace-folder . --frozen-lockfile
devcontainer exec --workspace-folder . npm test

# Check and bump Feature versions
devcontainer outdated --workspace-folder .
devcontainer upgrade --workspace-folder .
```
Then point `image` at the pushed tag (or use `build.cacheFrom`) so editors pull instead of rebuild.
`--frozen-lockfile` fails if `devcontainer-lock.json` is missing or would change.

## Rules
- Pin base image and Feature majors; commit `devcontainer-lock.json`.
- Use `remoteEnv` with `${localEnv:VAR}` or Codespaces secrets for tokens; never hard-code them
  in `containerEnv`, a Dockerfile, or the image.
- Put dependency installs in `onCreateCommand`/`updateContentCommand` so prebuilds cache them;
  keep `postCreateCommand` for steps that need the user or their secrets.
- Prefer `forwardPorts` over `appPort`; bind servers to `0.0.0.0`, not `127.0.0.1`.
- Run as a non-root `remoteUser`; leave `updateRemoteUserUID` at its default `true` on Linux.
- Keep `docker-in-docker` (isolated daemon) and `docker-outside-of-docker` (host socket) as an
  explicit choice; the host socket gives the container root-equivalent host access.

## Common Mistakes
- **Container exits immediately with Compose.** No long-running `command`; add `sleep infinity`.
- **`workspaceFolder` is `/` with Compose.** It defaults to `/`; set it to the mounted path.
- **Changed `containerEnv` has no effect.** It is baked at create time; rebuild the container.
  `remoteEnv` changes apply without a rebuild.
- **Codespace starts slow despite prebuilds.** Installs live in `postCreateCommand`, which never
  runs during a prebuild; move them to `onCreateCommand` or `updateContentCommand`.
- **Files created in the container are owned by root on the host.** Set `remoteUser` to the
  image's non-root user instead of running as root.
- **A Feature's tool is not on `PATH` in `postCreateCommand`.** It was installed for a different
  user; check the Feature's options and `remoteUser`, and use a login shell (`bash -lc`).

## Verify
```bash
devcontainer read-configuration --workspace-folder . >/dev/null && echo "config parses"
devcontainer up --workspace-folder . --remove-existing-container
devcontainer exec --workspace-folder . bash -lc 'node --version && npm test'
```
- Confirm each lifecycle hook ran once (check the creation log) and forwarded ports answer.
- In Codespaces, create a codespace from a prebuild and confirm `npm ci` did not run again.
