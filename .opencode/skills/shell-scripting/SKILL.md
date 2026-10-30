---
name: shell-scripting
description: "Use when writing, reviewing, or debugging Bash/sh scripts — set -euo pipefail, quoting and word splitting, arrays, getopts/argument parsing, trap cleanup, mktemp, functions, exit codes, GNU vs BSD tool differences, and ShellCheck."
license: MIT
---

# Shell Scripting

## When to Use This Skill
- Automation glue, CI steps, install scripts, cron jobs
- Scripts that break on filenames with spaces or empty variables
- Making scripts work on both macOS (BSD) and Linux (GNU)

## Template
```bash
#!/usr/bin/env bash
set -Eeuo pipefail

usage() { echo "Usage: $(basename "$0") [-v] -e <env> <file>..." >&2; exit 2; }

verbose=0 env=""
while getopts ":ve:h" opt; do
  case $opt in
    v) verbose=1 ;;
    e) env=$OPTARG ;;
    h|*) usage ;;
  esac
done
shift $((OPTIND - 1))
[[ -n $env && $# -gt 0 ]] || usage

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
trap 'echo "error on line $LINENO" >&2' ERR

log() { (( verbose )) && printf '%s\n' "$*" >&2 || true; }

for file in "$@"; do
  log "processing $file"
  cp -- "$file" "$tmp/"
done
```

## Quoting
- Quote every expansion: `"$var"`, `"$@"`, `"$(cmd)"`.
- Use arrays for argument lists: `args=(--flag "$value"); cmd "${args[@]}"`.
- `[[ ]]` in Bash for tests; `[ ]` only for POSIX sh.
- Defaults: `${VAR:-default}`; required: `${VAR:?VAR must be set}`.

## Pitfalls
- `set -e` doesn't trigger inside `if`, `&&`, `||` conditions or command substitutions in some contexts — check critical commands explicitly.
- `cmd | while read` runs the loop in a subshell; use `while read -r line; do …; done < <(cmd)`.
- `read` without `-r` mangles backslashes; use `IFS= read -r`.
- Parsing `ls` output breaks on spaces — use globs or `find -print0 | xargs -0`.
- `echo -e` is non-portable; use `printf`.

## Portability
- `sed -i` differs: GNU `sed -i 's/a/b/' f` vs BSD `sed -i '' 's/a/b/' f`.
- `date`, `readlink -f`, `stat`, `grep -P` differ between GNU and BSD.
- Target `#!/bin/sh` only if you avoid Bash features; otherwise say `bash`.

## Rules
- Run `shellcheck` on every script; fix rather than disable warnings.
- Send logs and errors to stderr; stdout is for data.
- Exit non-zero on failure with a clear message.
- If a script exceeds ~150 lines or needs data structures, consider Python.
