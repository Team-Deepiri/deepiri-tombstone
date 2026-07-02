#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPLAY="$ROOT/src/replay/fallback.sh"
errors=0

echo "=== Replay tests ==="

# Test missing ledger
result=$(bash "$REPLAY" "/nonexistent/ledger" 2>&1 || true)
if echo "$result" | grep -q "Usage"; then
  echo "  PASS: missing ledger shows usage"
else
  echo "  FAIL: missing ledger should show usage"
  errors=$((errors + 1))
fi

# Test basic replay with ledger
result=$(bash "$REPLAY" "$ROOT/reports/audit.ledger" 2>&1 || true)
if echo "$result" | grep -q "Replay report"; then
  echo "  PASS: basic replay has header"
else
  echo "  FAIL: basic replay should have header"
  errors=$((errors + 1))
fi

# Test pass rate in output
if echo "$result" | grep -q "Pass rate"; then
  echo "  PASS: output contains pass rate"
else
  echo "  FAIL: output should contain pass rate"
  errors=$((errors + 1))
fi

# Test count of entries
if echo "$result" | grep -q "Replayed"; then
  echo "  PASS: output shows replayed count"
else
  echo "  FAIL: output should show replayed count"
  errors=$((errors + 1))
fi

# Test replay.py --help
if command -v python3 &>/dev/null; then
  help_out=$(python3 "$ROOT/src/replay/replay.py" --help 2>&1 || true)
  if echo "$help_out" | grep -q "replay"; then
    echo "  PASS: replay.py --help works"
  else
    echo "  FAIL: replay.py --help should work"
    errors=$((errors + 1))
  fi
fi

# Test compare mode flag exists
if echo "$help_out" | grep -q "compare"; then
  echo "  PASS: --compare flag documented"
else
  echo "  FAIL: --compare flag should be documented"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL REPLAY TESTS PASSED"
else echo "$errors REPLAY TEST(S) FAILED"; fi
exit "$errors"
