# Shell Setup Guide

<!--toc:start-->
- [Shell Setup Guide](#shell-setup-guide)
  - [Option 1: Setup Script](#option-1-setup-script)
  - [Option 2: Manual Setup](#option-2-manual-setup)
  - [Usage](#usage)
<!--toc:end-->

## Option 1: Setup Script

Run the included script to configure shell functions for occontained:

```bash
~/OC_Contained/setup_shell.sh
```

The script configures your shell for occontained:

1. **Shell Detection**: Detects if you use Zsh or Bash, and updates the configuration file (`~/.zshrc` or `~/.bashrc`). Fish is not supported.
2. **Function Installation**: Creates `~/.local/bin/occontained-functions.sh` with the required Podman functions.
3. **Auto-Sourcing**: Adds a `source` command to load these functions in new terminal sessions.
4. **Setup Confirmation**: Prints the path of the configured file.

The generated functions use Podman with host networking and:
- User namespace mapping (creates files with your host user ID)
- Pinned `HOME`/`XDG_*` paths (so OpenCode reads the mounted config and auth files)
- SSH key forwarding (for Git operations inside the container)
- Configuration persistence (saves your opencode settings)
- Authentication token sharing (so you do not need to log in again)

Reload your shell:

```bash
source ~/.zshrc   # or ~/.bashrc
```

## Option 2: Manual Setup

Add these functions directly to your `~/.zshrc` or `~/.bashrc` file:

```bash
occontained() {
  podman run -d \
    --name occontained \
    --rm \
    --user "$(id -u):$(id -g)" \
    --network=host \
    --memory=12g --memory-swap=15g \
    --pids-limit=512 \
    --cpus=6 \
    -w /workspace \
    -v "${OPENCODE_PATH:-$(pwd)}:/workspace" \
    -v "$HOME/.ssh/id_ed25519:/home/occontained/.ssh/id_ed25519:ro" \
    -v "$HOME/.config/opencode:/home/occontained/.config/opencode" \
    -v "$HOME/.local/share/opencode/auth.json:/home/occontained/.local/share/opencode/auth.json" \
    -e "HOME=/home/occontained" \
    -e "XDG_CONFIG_HOME=/home/occontained/.config" \
    -e "XDG_DATA_HOME=/home/occontained/.local/share" \
    -e "GH_TOKEN=${GH_TOKEN:-}" \
    -e "OPENCODE_SERVER_USERNAME=${OPENCODE_SERVER_USERNAME:-opencode}" \
    -e "OPENCODE_SERVER_PASSWORD=${OPENCODE_SERVER_PASSWORD:-}" \
    ghcr.io/nikkidreams/opencode-contained:latest web --hostname 0.0.0.0 --port "${OPENCODE_PORT:-4096}"
}

occontained_tui() {
  podman run -it \
    --rm \
    --name occontained-tui \
    --user "$(id -u):$(id -g)" \
    --network=host \
    --memory=12g --memory-swap=15g \
    --pids-limit=512 \
    --cpus=6 \
    -w /workspace \
    -v "${OPENCODE_PATH:-$(pwd)}:/workspace" \
    -v "$HOME/.ssh/id_ed25519:/home/occontained/.ssh/id_ed25519:ro" \
    -v "$HOME/.config/opencode:/home/occontained/.config/opencode" \
    -v "$HOME/.local/share/opencode/auth.json:/home/occontained/.local/share/opencode/auth.json" \
    -e "HOME=/home/occontained" \
    -e "XDG_CONFIG_HOME=/home/occontained/.config" \
    -e "XDG_DATA_HOME=/home/occontained/.local/share" \
    -e "GH_TOKEN=${GH_TOKEN:-}" \
    ghcr.io/nikkidreams/opencode-contained:latest
}
```

> [!NOTE]
> With `--network=host`, `-p` mappings are no-ops. The web port is set on the `web` command itself (`--port`).

Reload your shell:

```bash
source ~/.zshrc   # or ~/.bashrc
```

## Usage

```bash
# Start web mode
occontained

# Start terminal mode
occontained_tui

# Set a custom port
OPENCODE_PORT=5000 occontained

# Set a custom project path
OPENCODE_PATH=/path/to/project occontained

# Set both port and project path
OPENCODE_PORT=5000 OPENCODE_PATH=/path/to/project occontained

# Stop the container
podman stop occontained
```
