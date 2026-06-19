#!/usr/bin/env bash
# Compare two audit ledger files and show diff
set -euo pipefail

ledger1="${1:-reports/audit.ledger}"
ledger2="${2:-reports/audit.ledger}"

if [[ ! -f "$ledger1" ]]; then echo "File not found: $ledger1"; exit 1; fi
if [[ ! -f "$ledger2" ]]; then echo "File not found: $ledger2"; exit 1; fi

echo "=== Comparison ==="
echo "1: $ledger1 ($(wc -l < "$ledger1") records)"
echo "2: $ledger2 ($(wc -l < "$ledger2") records)"

# Extract LATENCY-MS and STATUS columns (positions 5 and 6 in pipe-delimited)
if [[ "$ledger1" == "$ledger2" ]]; then
  echo "Same file — showing stats only"
else
  echo ""
  echo "Records in 1 not in 2:"
  diff --new-line-format="" --unchanged-line-format="" <(sort "$ledger1") <(sort "$ledger2") || true
  echo ""
  echo "Records in 2 not in 1:"
  diff --new-line-format="" --unchanged-line-format="" <(sort "$ledger2") <(sort "$ledger1") || true
fi

# Summary stats
echo ""
echo "=== Summary ==="
for f in "$ledger1" "$ledger2"; do
  pass=$(grep -c "|PASS" "$f" 2>/dev/null || echo 0)
  fail=$(grep -c "|FAIL" "$f" 2>/dev/null || echo 0)
  total=$(wc -l < "$f")
  echo "$(basename "$f"): $total records, $pass pass, $fail fail"
done
