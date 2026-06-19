#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v inotifywait >/dev/null 2>&1; then
  inotifywait -q -m -e modify,create,delete \
    src/ scripts/ Makefile 2>/dev/null || {
    echo "watch: install inotify-tools or run: while true; do make; sleep 2; done"
    exit 1
  }
else
  while true; do make; sleep 2; done
fi
