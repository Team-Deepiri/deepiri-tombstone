#!/usr/bin/env bash
set -euo pipefail
FIXTURE="${1:-}"
MODEL="${2:-${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}}"
JOBS="${3:-4}"
if [[ -z "$FIXTURE" || ! -f "$FIXTURE" ]]; then
  echo "Usage: runner <fixture> [model] [jobs]" >&2
  exit 1
fi
echo "# Parallel runner (fallback)"
echo "# Model: $MODEL, Fixture: $FIXTURE"
total=$(grep -c -v '^#' "$FIXTURE" || true)
passes=0
while IFS='|' read -r prompt keyword; do
  [[ -z "$prompt" || "$prompt" == \#* ]] && continue
  resp=$(curl -sf "http://${DEEPIRI_TOMBSTONE_HOST:-127.0.0.1:11434}/api/generate" \
    -d "{\"model\":\"$MODEL\",\"prompt\":\"$prompt\",\"stream\":false}" 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo "")
  if echo "$resp" | grep -qi "$keyword"; then passes=$((passes + 1)); fi
done < "$FIXTURE"
echo "# Results: $passes/$total passed"
echo "{\"pass_rate\":$((passes * 100 / (total > 0 ? total : 1))),\"passes\":$passes,\"total\":$total}"
