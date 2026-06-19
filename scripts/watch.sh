#!/usr/bin/env bash
# Watch source files and rebuild on change
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Watching for changes (Ctrl+C to stop)..."
while true; do
  inotifywait -q -r -e modify -e create -e delete \
    b/ c/ cobol/ fortran/ forth/ awk/ perl/ bcpl/ scripts/ Makefile 2>/dev/null || {
    # fallback: poll every 5s
    sleep 5
  }
  echo "Change detected, rebuilding..."
  make 2>&1 | tail -3
done
