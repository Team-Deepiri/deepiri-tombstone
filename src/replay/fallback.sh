#!/usr/bin/env bash
set -euo pipefail
LEDGER="${1:-reports/audit.ledger}"
MODEL="${2:-${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}}"
if [[ ! -f "$LEDGER" ]]; then
  echo "Usage: replay <ledger> [model]" >&2
  exit 1
fi
echo "# Replay report"
echo "# Source: $LEDGER"
echo "# Model: $MODEL"
total=0
passes=0
while IFS='|' read -r runid model prompt resp lat status; do
  [[ -z "$runid" || "$runid" == \#* ]] && continue
  total=$((total + 1))
  [[ "$status" == "PASS" ]] && passes=$((passes + 1))
done < "$LEDGER"
echo "# Replayed: $total entries, $passes passes"
[[ $total -gt 0 ]] && echo "# Pass rate: $((passes * 100 / total))%"
exit 0
