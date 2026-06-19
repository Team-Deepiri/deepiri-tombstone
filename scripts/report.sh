#!/usr/bin/env bash
# Generate a human-readable report from the audit ledger
set -euo pipefail

LEDGER="${1:-reports/audit.ledger}"

if [[ ! -f "$LEDGER" ]]; then
  echo "Audit ledger not found: $LEDGER"
  echo "Run an eval first: deepiri-tombstone eval"
  exit 1
fi

echo "=== Audit ledger report ==="
echo "File: $LEDGER"
echo "Records: $(wc -l < "$LEDGER")"
echo ""
while IFS= read -r line; do
  echo "$line"
done < "$LEDGER"
echo ""
echo "=== End of report ==="
