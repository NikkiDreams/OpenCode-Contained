# OpenCode Contained Development Environment

## Forked and Updated for Podman and Local Inference

This is a forked version of [OpenCoded](https://github.com/brockar/opencoded) originally by Martin Guzman. This fork is refactored to run OpenCode in a Podman container using local models provided by a Local LLM Runtime like Strata, Ollama, LM Studio, llama.cpp or any LLM Runtime with a local API. Your models, your private environments. You can use easily use abliterated models (not recommended)) if you are really trying to be the "edgy". And ZERO tokens sucking the life out of your bank account. However if you need remote models or cannot run an LLM localy, this option is still available.

<!--toc:start-->
- [OpenCode Contained Development Environment](#opencode-contained-development-environment)
  - [Forked and Updated for Podman and Local Inference](#forked-and-updated-for-podman-and-local-inference)
  - [Features](#features)
  - [Quick Start](#quick-start)
    - [Clone the repository](#clone-the-repository)
    - [Prerequisites](#prerequisites)
    - [Optional Prerequisites](#optional-prerequisites)
    - [Use Podman Compose](#use-podman-compose)
    - [Use the helper script](#use-the-helper-script)
  - [Podman Run Examples](#podman-run-examples)
    - [Web Server](#web-server)
    - [TUI Mode](#tui-mode)
  - [Configuration](#configuration)
    - [Web authentication](#web-authentication)
    - [Helper Script Environment Variables](#helper-script-environment-variables)
    - [Volume Mounts](#volume-mounts)
    - [Environment Variables](#environment-variables)
  - [Shell Alias](#shell-alias)
  - [Customize the Container Image](#customize-the-container-image)
<!--toc:end-->

![OpenCode Banner](docs/assets/banner.webp)

This container runs [OpenCode](https://opencode.ai) inside Podman. You can run OpenCode in web mode or terminal mode. The container includes all dependencies and isolates your environment.

## Features

- **Web interface**: Open OpenCode in your browser.
- **TUI mode**: Run OpenCode directly in your terminal.
- **Multiple instances**: Run multiple containers at the same time on different ports. See the [multiple instances guide](docs/multiple_instances.md).
- **Persistent configuration**: Save your OpenCode settings and authentication across container restarts.
- **Git integration**: Mount SSH keys to use Git commands.
- **Project isolation**: Separate projects into distinct containers.

## Quick Start

### Clone the repository

```bash
git clone https://github.com/NikkiDreams/OpenCode-Contained.git ~/OC_Contained
cd ~/OC_Contained
```

### Prerequisites

Before you run the container, make sure you have these items:

- An LLM running locally with an API endpoint like `http://127.0.0.1:8080/v1`
- An SSH key at `~/.ssh/id_ed25519` for Git commands inside the container.
- A web interface password in `OPENCODE_SERVER_PASSWORD`. Web mode refuses to start without one. See [Web authentication](#web-authentication).

### Optional Prerequisites

- Configured OpenCode authentication. See the [configuration section](#configuration).

### Use Podman Compose

Create a git-ignored `.env` file with a web password (`podman compose` reads `.env` from this directory automatically):

```bash
cp .env.example .env
sed -i "s|^OPENCODE_SERVER_PASSWORD=$|OPENCODE_SERVER_PASSWORD=$(openssl rand -hex 24)|" .env
```

Then run this command:

```bash
podman compose up -d
```

Open the web interface at **<http://localhost:4096>** (or `http://localhost:${OPENCODE_PORT}` if set) and log in with `opencode` and the password from `.env`. Without `OPENCODE_SERVER_PASSWORD`, compose refuses to start rather than serving an open web UI.

### Use the helper script

`run.sh` also reads `.env` from the repository directory. Run the helper script:

```bash
~/OC_Contained/run.sh
```

To run the container for a specific project:

```bash
PROJECT_PATH=/path/to/project ~/OC_Contained/run.sh
```

## Podman Run Examples

### Web Server

Run the web server container:

```bash
# Export secrets before running so their values never appear in the podman
# process argv (visible in `ps`) or in the command line you typed. The
# `:?` guard stops here if no password is set.
export GH_TOKEN="${GH_TOKEN:-}"
export OPENCODE_SERVER_USERNAME="${OPENCODE_SERVER_USERNAME:-opencode}"
export OPENCODE_SERVER_PASSWORD="${OPENCODE_SERVER_PASSWORD:?web mode requires a password}"

podman run -d \
  --name occontained \
  --rm \
  --user "$(id -u):$(id -g)" \
  --network=host \
  --memory=12g --memory-swap=15g \
  --pids-limit=512 \
  -w /workspace \
  -v $(pwd):/workspace \
  -v ~/.ssh/id_ed25519:/home/occontained/.ssh/id_ed25519:ro \
  -v ~/.config/opencode:/home/occontained/.config/opencode \
  -v ~/.local/share/opencode/auth.json:/home/occontained/.local/share/opencode/auth.json \
  -e HOME=/home/occontained \
  -e XDG_CONFIG_HOME=/home/occontained/.config \
  -e XDG_DATA_HOME=/home/occontained/.local/share \
  -e GH_TOKEN \
  -e OPENCODE_SERVER_USERNAME \
  -e OPENCODE_SERVER_PASSWORD \
  ghcr.io/nikkidreams/opencode-contained:latest web --hostname "${OPENCODE_BIND:-127.0.0.1}" --port "${OPENCODE_PORT:-4096}"
```

With `--network=host`, `-p` mappings are no-ops, so the port and the bind address are set on the server command. The server binds `127.0.0.1` by default, so open **<http://localhost:4096>** (or `http://localhost:${OPENCODE_PORT}` if you set `OPENCODE_PORT`) and log in with `opencode` plus `OPENCODE_SERVER_PASSWORD`.

Local LLM APIs still work with a loopback bind: host networking shares the host's loopback, so the container reaches `http://127.0.0.1:8080/v1` the same way it always did. To let another machine open the interface, bind every interface deliberately:

```bash
export OPENCODE_SERVER_PASSWORD='your-password'   # avoids leaking it into `ps`
OPENCODE_BIND=0.0.0.0 ~/OC_Contained/run.sh
```

Anyone on your network can reach `0.0.0.0`, so keep a strong password and only set `OPENCODE_BIND` when you need it.

### TUI Mode

Run OpenCode in terminal mode:

```bash
export GH_TOKEN="${GH_TOKEN:-}"   # keeps the token out of `ps` (argv)

podman run -it \
  --rm \
  --user "$(id -u):$(id -g)" \
  -w /workspace \
  -v $(pwd):/workspace \
  -v ~/.ssh/id_ed25519:/home/occontained/.ssh/id_ed25519:ro \
  -v ~/.config/opencode:/home/occontained/.config/opencode \
  -v ~/.local/share/opencode/auth.json:/home/occontained/.local/share/opencode/auth.json \
  -e HOME=/home/occontained \
  -e XDG_CONFIG_HOME=/home/occontained/.config \
  -e XDG_DATA_HOME=/home/occontained/.local/share \
  -e GH_TOKEN \
  ghcr.io/nikkidreams/opencode-contained:latest
```

This command starts the terminal interface. Press `Ctrl+C` or type `/exit` to stop the container.

## Configuration

### Web authentication

Web mode always runs behind a login, and it binds `127.0.0.1` unless you ask otherwise. `OPENCODE_SERVER_PASSWORD` has no default, so every entry point stops before starting an open server:

| Entry point | Where the password comes from | Behaviour when unset |
| --- | --- | --- |
| `run.sh` | shell environment, or `.env` in the repository directory | prints an error and exits before creating a container |
| `podman compose up -d` | shell environment, or `.env` in the repository directory | compose refuses with "web mode requires a password" |
| `occontained` shell function | shell environment (export it in your rc file) | prints an error and returns 1 |
| `podman run ... web ...` | exported shell variable (the example exports it with `${VAR:?...}` before running) | bash stops you before `podman run` executes |

Keep secret values out of command lines: pass podman a bare `-e OPENCODE_SERVER_PASSWORD` (podman inherits the exported value) instead of `-e OPENCODE_SERVER_PASSWORD=...`, and export variables on their own line instead of prefixing them to a command. Values written on a command line appear in the process argv, which any local user can read with `ps`, and stay in your shell history. Container environment values remain visible to `podman inspect`; that is inherent to containers, but they are no longer exposed through `ps` or history.

Generate a password once and keep it out of git (`.env` is git-ignored):

```bash
openssl rand -hex 24   # copy the output into .env, or export OPENCODE_SERVER_PASSWORD
```

Log in with `OPENCODE_SERVER_USERNAME` (default `opencode`) and that password. TUI mode starts no server, so it needs no password: use `occontained_tui`, or run the image with no `web` command. `.env.example` documents every supported variable.

### Helper Script Environment Variables

| Variable        | Description                     | Default    |
| --------------- | ------------------------------- | ---------- |
| `PROJECT_PATH`  | Path to project directory       | `$(pwd)`   |
| `OPENCODE_PORT` | Host port to expose             | `4096`     |
| `OPENCODE_BIND` | Web UI bind address (`127.0.0.1` keeps it localhost only) | `127.0.0.1` |
| `OC_IMAGE`      | Container image to run          | `ghcr.io/nikkidreams/opencode-contained:latest` |
| `CUSTOM_UID`    | User ID for file permissions    | `$(id -u)` |
| `CUSTOM_GID`    | Group ID for file permissions   | `$(id -g)` |

### Volume Mounts

The container mounts these volumes:

- Project directory: `/workspace`
- `~/.ssh/id_ed25519`: SSH key for Git operations (mounted to `/home/occontained/.ssh`)
- `~/.config/opencode`: OpenCode settings (mounted to `/home/occontained/.config/opencode`)
- `~/.local/share/opencode/auth.json`: OpenCode authentication file (mounted to `/home/occontained/.local/share/opencode`)

The example commands set `HOME`, `XDG_CONFIG_HOME`, and `XDG_DATA_HOME` to `/home/occontained`. This is required: when running with `--user`, the host UID is usually not in the image's `/etc/passwd`, so the container `HOME` falls back to `/` and OpenCode would never see the mounts. Keep these env vars aligned with the mount targets.

> [!TIP]
> **Save session history:** The container mounts `auth.json` by default. Mount the full directory to save conversation history:
>
> ```bash
> -v ~/.local/share/opencode:/home/occontained/.local/share/opencode
> ```
>
> [!TIP]
> **Mount your parent code directory:** Mount your `~/code` directory as the workspace. This allows you to open any project in the web interface without restarting the container:
>
> ```bash
> -v ~/code:/workspace
> ```
>
> Open the specific project directory inside the interface.

### Environment Variables

| Variable                   | Description                               | Default    |
| -------------------------- | ----------------------------------------- | ---------- |
| `GH_TOKEN`                 | GitHub token (optional)                   | -          |
| `OPENCODE_SERVER_USERNAME` | Username for web interface authentication | `opencode` |
| `OPENCODE_SERVER_PASSWORD` | Password for web interface authentication | **required for web mode** |

## Shell Alias

Run the setup script to configure shell aliases automatically. The script detects Zsh or Bash:

```bash
~/OC_Contained/setup_shell.sh
```

Reload your shell after the script finishes. See the [shell setup guide](docs/shell-setup.md) for manual setup steps.

## Customize the Container Image

To add packages to the standard image, edit `Containerfile`:

```containerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
  your-package-here \
  && rm -rf /var/lib/apt/lists/*
```

To add packages to the slim image, edit `Containerfile.slim`:

```containerfile
RUN apk add --no-cache your-package-here
```

Rebuild the image locally:

```bash
# Standard image
podman build -t ghcr.io/nikkidreams/opencode-contained:latest .
# Slim image
podman build -f Containerfile.slim -t ghcr.io/nikkidreams/opencode-contained:slim .
```

> [!NOTE]
> Combine `apt-get install` with `rm -rf /var/lib/apt/lists/*` in the same `RUN` instruction to keep the image size small.
