#!/usr/bin/env bash
set -euo pipefail

# Load .env from this script's directory when present (the same file Podman
# Compose reads automatically). Everything in it is exported so the defaults
# below can pick the values up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/.env"
  set +a
fi

### VARIABLES
HOST_UID="${CUSTOM_UID:-$(id -u)}"
HOST_GID="${CUSTOM_GID:-$(id -g)}"
PORT="${OPENCODE_PORT:-4096}"
# Bind to loopback by default. With --network=host the container shares the
# host's network namespace, so a server bound to 0.0.0.0 is reachable from
# every device on the LAN. Outbound access to local LLM APIs is NOT affected:
# host networking also shares the host's loopback, so the container can still
# reach http://127.0.0.1:<llm-port>. Set OPENCODE_BIND=0.0.0.0 deliberately if
# you want the web UI reachable from another machine.
BIND="${OPENCODE_BIND:-127.0.0.1}"
PROJECT_PATH="${PROJECT_PATH:-$(pwd)}"
CONTAINER_NAME="occontained"
IMAGE="${OC_IMAGE:-ghcr.io/nikkidreams/opencode-contained:latest}"
SERVER_USERNAME="${OPENCODE_SERVER_USERNAME:-opencode}"
OC_AUTH_PATH="$HOME/.local/share/opencode/auth.json"
# Container home must be pinned explicitly: with --user (host UID not in the
# image's /etc/passwd) the container HOME falls back to "/", so OpenCode's
# XDG paths would never match the mounts below.
CONTAINER_HOME="/home/occontained"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Web mode must never start without authentication: --network=host plus a
# server bound on a non-loopback address exposes the agent to the whole LAN.
# Fail here instead of silently launching an open server.
if [ -z "${OPENCODE_SERVER_PASSWORD:-}" ]; then
  echo -e "${RED}ERROR: OPENCODE_SERVER_PASSWORD is not set; web mode would start with no authentication.${NC}" >&2
  echo -e "Set a password first, for example:" >&2
  echo -e "  ${CYAN}export OPENCODE_SERVER_PASSWORD=\"\$(openssl rand -hex 24)\"${NC}" >&2
  echo -e "Or keep it stable across restarts in ${CYAN}.env${NC} (see ${CYAN}.env.example${NC}), which is git-ignored." >&2
  echo -e "Terminal mode needs no password: ${CYAN}podman run -it --rm <image>${NC} or ${CYAN}occontained_tui${NC}." >&2
  exit 1
fi

# Pass secrets to podman as bare `-e NAME` (inherit from the environment)
# instead of `-e NAME=value`. Values written on the command line land in the
# podman process argv, which any local user can read through `ps`, and they
# linger in shell history when typed inline. Exporting keeps the values in
# this shell's environment only. (They remain visible in `podman inspect`;
# that is inherent to containers and not reachable from `ps`.)
# GH_TOKEN is exported only when set: podman passes an unset variable
# through as absent, which is better than handing the container an empty token.
if [ -n "${GH_TOKEN:-}" ]; then export GH_TOKEN; fi
export OPENCODE_SERVER_USERNAME="$SERVER_USERNAME"
export OPENCODE_SERVER_PASSWORD

echo -e "${BLUE}Setting up OpenCode Container environment...${NC}"
mkdir -p ~/.config/opencode
mkdir -p ~/.local/share/opencode
mkdir -p ~/.ssh
echo -e "${GREEN}Directories created.${NC}"

if [ ! -f "$OC_AUTH_PATH" ]; then
  echo -e "${YELLOW}Creating empty auth.json...${NC}"
  echo '{}' >"$OC_AUTH_PATH"
  echo -e "${GREEN}auth.json created at $OC_AUTH_PATH${NC}"
else
  echo -e "${GREEN}auth.json already exists.${NC}"
fi

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  echo -e "${YELLOW}WARNING: ~/.ssh/id_ed25519 not found. Git operations may not work.${NC}"
  echo -e "Generate one with:"
  echo -e "${CYAN}ssh-keygen -t ed25519 -C 'your@email.com'${NC}"
fi

if podman ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo ""
  echo -e "${YELLOW}Container '${CONTAINER_NAME}' already exists.${NC}"
  echo -e "Stopping and removing existing container..."
  podman stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
  podman rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
  echo -e "${GREEN}Existing container removed.${NC}"
fi

echo ""
echo -e "${BLUE}Project path: ${PROJECT_PATH}${NC}"
echo -e "${BLUE}Starting OpenCode container on port $PORT...${NC}"

# --network=host is intentional: it lets the container reach local LLM runtimes
# and the internet directly. With host networking, "-p" mappings are no-ops, so
# both the port and the bind address are controlled here, on the server command.
if [ "$BIND" != "127.0.0.1" ] && [ "$BIND" != "localhost" ]; then
  echo -e "${YELLOW}WARNING: OPENCODE_BIND=$BIND exposes the web UI on your network. Anyone on the LAN can reach it (log in as $SERVER_USERNAME).${NC}"
fi

podman run -d \
  --name "$CONTAINER_NAME" \
  --rm \
  --user "$HOST_UID:$HOST_GID" \
  --network=host \
  --memory=12g --memory-swap=15g \
  --pids-limit=512 \
  --cpus=6 \
  -w /workspace \
  -v "${PROJECT_PATH}:/workspace" \
  -v "$HOME/.ssh/id_ed25519:${CONTAINER_HOME}/.ssh/id_ed25519:ro" \
  -v "$HOME/.config/opencode:${CONTAINER_HOME}/.config/opencode" \
  -v "$HOME/.local/share/opencode/auth.json:${CONTAINER_HOME}/.local/share/opencode/auth.json" \
  -e "HOME=${CONTAINER_HOME}" \
  -e "XDG_CONFIG_HOME=${CONTAINER_HOME}/.config" \
  -e "XDG_DATA_HOME=${CONTAINER_HOME}/.local/share" \
  -e GH_TOKEN \
  -e OPENCODE_SERVER_USERNAME \
  -e OPENCODE_SERVER_PASSWORD \
  "$IMAGE" web --hostname "$BIND" --port "$PORT"

echo ""
echo -e "${GREEN}OpenCode is starting!${NC}"
if [ "$BIND" = "127.0.0.1" ] || [ "$BIND" = "localhost" ]; then
  echo -e "Access the web interface at: ${CYAN}http://localhost:$PORT${NC} (localhost only)"
  echo -e "To reach it from another machine: ${CYAN}OPENCODE_BIND=0.0.0.0 ~/OC_Contained/run.sh${NC}"
else
  echo -e "Access the web interface at: ${CYAN}http://$BIND:$PORT${NC}"
fi
echo -e "Login with username ${CYAN}$SERVER_USERNAME${NC} and your ${CYAN}OPENCODE_SERVER_PASSWORD${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  ${CYAN}podman logs -f $CONTAINER_NAME${NC}  - View logs"
echo -e "  ${CYAN}podman stop $CONTAINER_NAME${NC}    - Stop container"
