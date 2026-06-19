#!/usr/bin/env bash
# Archive old reports to reports/archive/
set -euo pipefail
ARCHIVE="reports/archive"
mkdir -p "$ARCHIVE"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
for f in reports/audit.ledger reports/stats.dat reports/summary.txt; do
  if [[ -f "$f" ]]; then
    cp "$f" "$ARCHIVE/$(basename "$f").$TIMESTAMP"
    > "$f"  # truncate but keep file
    echo "Archived $f"
  fi
done
echo "Reports archived to $ARCHIVE/"
