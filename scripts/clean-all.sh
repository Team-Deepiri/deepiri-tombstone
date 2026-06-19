#!/usr/bin/env bash
# Clear all generated data and build artifacts
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Clearing reports..."
rm -f reports/audit.ledger reports/stats.dat reports/summary.txt
rm -rf reports/archive/
echo "Clearing build artifacts..."
make clean 2>/dev/null || true
rm -f bin/.gitkeep
echo "Done. Run 'make' to rebuild."
