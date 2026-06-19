#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== deepiri-tombstone stats ==="
echo "commits: $(git rev-list --count HEAD 2>/dev/null || echo '?')"
echo "fixtures: $(find fixtures -type f ! -name 'README.md' 2>/dev/null | wc -l)"
echo ""

echo "=== source lines by stage ==="
for stage in orchestrator bridge tokenize parse score audit request transport; do
  count=$(find "src/$stage" -type f ! -name 'fallback.sh' -exec cat {} + 2>/dev/null | wc -l)
  printf "  %-14s %s\n" "$stage" "$count"
done
