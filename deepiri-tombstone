#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ ! -x "$ROOT/bin/deepiri-tombstone-core" ]]; then
  ROOT="$(cd "$ROOT/.." && pwd)"
fi
cd "$ROOT"
export DEEPIRI_TOMBSTONE_CMD="${1:-}"
export DEEPIRI_TOMBSTONE_ARG1="${2:-}"
export DEEPIRI_TOMBSTONE_ARG2="${3:-}"
exec "$ROOT/bin/deepiri-tombstone-core"
