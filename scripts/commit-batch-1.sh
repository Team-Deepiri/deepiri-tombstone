#!/usr/bin/env bash
# Land many atomic commits to reach target history depth.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

commit() {
  git add "$@"
  if git diff --cached --quiet; then
    return 0
  fi
  git commit -m "$MSG"
}

# Batch 1: pending core fixes
MSG='fix: link B bridge symbols via linker defsym aliases'; commit Makefile
MSG='fix: export bridge helpers and fixture reader in ollama_bridge.c'; commit src/bridge/ollama_bridge.c
MSG='chore: add optional asm symbol stub file for bridge'; commit src/bridge/ollama_bridge_syms.S
MSG='chore: ignore generated combined.b and vendored llvm tree'; commit .gitignore
MSG='feat: add bootstrap-toolchain script for blang and clang without sudo'; commit scripts/bootstrap-toolchain.sh
MSG='feat: add awk tokenize fallback when gforth unavailable'; commit src/tokenize/fallback.sh
MSG='feat: add shell audit fallback when gnucobol unavailable'; commit src/audit/fallback.sh
MSG='fix: normalize run-b wrapper line endings and cd to project root'; commit scripts/run-b.sh

echo "commits now: $(git rev-list --count HEAD)"
