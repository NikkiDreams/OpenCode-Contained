#!/usr/bin/env bash
set -euo pipefail

### VARIABLES
HOST_UID="${CUSTOM_UID:-$(id -u)}"
HOST_GID="${CUSTOM_GID:-$(id -g)}"
PORT="${OPENCODE_PORT:-4096}"
PROJECT_PATH="${PROJECT_PATH:-$(pwd)}"
CONTAINER_NAME="occontained"
IMAGE="${OC_IMAGE:-ghcr.io/nikkidreams/opencode-contained:latest}"
OC_AUTH_PATH="$HOME/.local/share/opencode/auth.json"
# Container home must be pinned explicitly: with --user (host UID not in the
# image's /etc/passwd) the container HOME falls back to "/", so OpenCode's
# XDG paths would never match the mounts below.
CONTAINER_HOME="/home/occontained"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
# the port is controlled here, on the server command, not via -p.
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
  -e "GH_TOKEN=${GH_TOKEN:-}" \
  -e "OPENCODE_SERVER_USERNAME=${OPENCODE_SERVER_USERNAME:-opencode}" \
  -e "OPENCODE_SERVER_PASSWORD=${OPENCODE_SERVER_PASSWORD:-}" \
  "$IMAGE" web --hostname 0.0.0.0 --port "$PORT"

echo ""
echo -e "${GREEN}OpenCode is starting!${NC}"
echo -e "Access the web interface at: ${CYAN}http://localhost:$PORT${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  ${CYAN}podman logs -f $CONTAINER_NAME${NC}  - View logs"
echo -e "  ${CYAN}podman stop $CONTAINER_NAME${NC}    - Stop container"
