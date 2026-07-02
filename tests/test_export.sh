#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

test_export() {
  local desc="$1" expected="$2"
  shift 2
  local output
  output=$("$@" 2>&1 || true)
  if echo "$output" | grep -q "$expected"; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc (expected pattern '$expected')"
    echo "    output: $(echo "$output" | head -c 300)"
    errors=$((errors + 1))
  fi
}

echo "=== Export tests ==="

test_export "json export" "run_id"  python3 "$ROOT/src/export/export.py" json --ledger "$ROOT/reports/audit.ledger"

test_export "json export has timestamp" "timestamp" python3 "$ROOT/src/export/export.py" json --ledger "$ROOT/reports/audit.ledger"

test_export "csv export" "run_id,model" python3 "$ROOT/src/export/export.py" csv --ledger "$ROOT/reports/audit.ledger"

test_export "csv has data rows" "run-001" python3 "$ROOT/src/export/export.py" csv --ledger "$ROOT/reports/audit.ledger"

test_export "md export has report" "Evaluation Report" python3 "$ROOT/src/export/export.py" md --ledger "$ROOT/reports/audit.ledger"

test_export "md shows pass rate" "Pass rate" python3 "$ROOT/src/export/export.py" md --ledger "$ROOT/reports/audit.ledger"

test_export "html export has html tag" "<html" python3 "$ROOT/src/export/export.py" html --ledger "$ROOT/reports/audit.ledger"

test_export "html shows summary cards" "Entries" python3 "$ROOT/src/export/export.py" html --ledger "$ROOT/reports/audit.ledger"

test_export "missing ledger reports error" "No entries found" python3 "$ROOT/src/export/export.py" json --ledger /tmp/nonexistent_ledger.dat

test_export "no args shows usage" "usage:" python3 "$ROOT/src/export/export.py"

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL EXPORT TESTS PASSED"
else echo "$errors EXPORT TEST(S) FAILED"; fi
exit "$errors"
