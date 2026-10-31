# Run Multiple Instances

You can run multiple OpenCode containers at the same time on different ports for different projects or accounts.

Each instance needs a unique container name, a unique port (set on the `web` command, since `--network=host` makes `-p` mappings no-ops), its own project directory, and a web password (`OPENCODE_SERVER_PASSWORD` has no default; see the [web authentication section](../README.md#web-authentication)).

```bash
# Export secrets once so their values never appear in the podman process
# argv (visible in `ps`). The `:?` guard stops before the runs below if no
# password is set. To use a different password per instance, re-export it
# between runs.
if [ -n "${GH_TOKEN:-}" ]; then export GH_TOKEN; fi   # exported only when set
export OPENCODE_SERVER_PASSWORD="${OPENCODE_SERVER_PASSWORD:?web mode requires a password}"

# Instance 1: Project A on port 4096
podman run -d \
  --name occontained-project-a \
  --rm \
  --user "$(id -u):$(id -g)" \
  --network=host \
  -w /workspace \
  -v /path/to/project-a:/workspace \
  -v ~/.ssh/id_ed25519:/home/occontained/.ssh/id_ed25519:ro \
  -v ~/.config/opencode:/home/occontained/.config/opencode \
  -v ~/.local/share/opencode/auth.json:/home/occontained/.local/share/opencode/auth.json \
  -e HOME=/home/occontained \
  -e XDG_CONFIG_HOME=/home/occontained/.config \
  -e XDG_DATA_HOME=/home/occontained/.local/share \
  -e GH_TOKEN \
  -e OPENCODE_SERVER_PASSWORD \
  ghcr.io/nikkidreams/opencode-contained:latest web --hostname "${OPENCODE_BIND:-127.0.0.1}" --port 4096

# Instance 2: Project B on port 4097
podman run -d \
  --name occontained-project-b \
  --rm \
  --user "$(id -u):$(id -g)" \
  --network=host \
  -w /workspace \
  -v /path/to/project-b:/workspace \
  -v ~/.ssh/id_ed25519:/home/occontained/.ssh/id_ed25519:ro \
  -v ~/.config/opencode:/home/occontained/.config/opencode \
  -v ~/.local/share/opencode/auth.json:/home/occontained/.local/share/opencode/auth.json \
  -e HOME=/home/occontained \
  -e XDG_CONFIG_HOME=/home/occontained/.config \
  -e XDG_DATA_HOME=/home/occontained/.local/share \
  -e GH_TOKEN \
  -e OPENCODE_SERVER_PASSWORD \
  ghcr.io/nikkidreams/opencode-contained:latest web --hostname "${OPENCODE_BIND:-127.0.0.1}" --port 4097
```

Open each instance in your browser and log in with `opencode` and `OPENCODE_SERVER_PASSWORD`:

- Project A: <http://localhost:4096>
- Project B: <http://localhost:4097>

> [!NOTE]
> `HOME`, `XDG_CONFIG_HOME`, and `XDG_DATA_HOME` must be pinned to `/home/occontained` so OpenCode resolves the mounted paths. With `--user`, the host UID is usually not in the image's `/etc/passwd`, so `HOME` would otherwise fall back to `/` and the mounts would never be read.

> [!TIP]
> Instances share `~/.config/opencode` and `auth.json`, so they use the same OpenCode settings and provider credentials. To fully separate instances (for example, different accounts), mount per-instance directories instead, such as `~/.config/opencode-project-a`.
