#!/usr/bin/env bash
# Show live evaluation progress
set -euo pipefail

LEDGER="${1:-reports/audit.ledger}"
TOTAL="${2:-}"
INTERVAL="${3:-2}"

if [[ ! -f "$LEDGER" ]]; then
  echo "Waiting for $LEDGER to appear..."
fi

echo "Watching $LEDGER..."
while true; do
  clear 2>/dev/null || true
  echo "=== Eval Progress ==="
  echo "Time: $(date '+%H:%M:%S')"
  if [[ -f "$LEDGER" ]]; then
    count=$(wc -l < "$LEDGER")
    pass=$(grep -c "|PASS" "$LEDGER" 2>/dev/null || echo 0)
    fail=$(grep -c "|FAIL" "$LEDGER" 2>/dev/null || echo 0)
    echo "Records: $count"
    [[ -n "$TOTAL" ]] && echo "Progress: $((count * 100 / TOTAL))%"
    echo "Pass: $pass  Fail: $fail"
  else
    echo "No records yet"
  fi
  if [[ -f reports/summary.txt ]]; then
    echo ""
    cat reports/summary.txt
  fi
  sleep "$INTERVAL"
done
