#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCORER="$ROOT/scripts/score_fallback.sh"
errors=0

test_score() {
  local latency="$1" response="$2" expected_pass="$3" name="$4"
  local resp_file="/tmp/dt_test_score.txt"
  echo "$response" > "$resp_file"
  result=$(bash "$SCORER" "$latency" "$resp_file" 2>/dev/null || true)
  pass=$(echo "$result" | grep -o 'pass=[0-1]' | cut -d= -f2)
  if [[ "$pass" == "$expected_pass" ]]; then
    echo "  PASS: $name"
  else
    echo "  FAIL: $name (expected pass=$expected_pass, got pass=$pass)"
    errors=$((errors + 1))
  fi
}

echo "=== Score tests ==="
rm -f reports/stats.dat reports/summary.txt
test_score "500" "hello world" "1" "non-empty response"
test_score "100" "" "0" "empty response"
test_score "0" "a" "1" "single char"
test_score "9999" "x" "1" "high latency"

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL SCORE TESTS PASSED"
else echo "$errors SCORE TEST(S) FAILED"; fi
exit "$errors"
