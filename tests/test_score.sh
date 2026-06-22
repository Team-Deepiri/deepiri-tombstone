#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCORER="$ROOT/src/score/fallback.sh"
errors=0

test_score() {
  local latency="$1" response="$2" expected_pass="$3" name="$4" category="${5:-}"
  local resp_file="/tmp/dt_test_score.txt"
  echo "$response" > "$resp_file"
  result=$(bash "$SCORER" "$latency" "$resp_file" "$category" 2>/dev/null || true)
  pass=$(echo "$result" | grep -o 'pass=[0-1]' | cut -d= -f2)
  if [[ "$pass" == "$expected_pass" ]]; then
    echo "  PASS: $name"
  else
    echo "  FAIL: $name (expected pass=$expected_pass, got pass=$pass)"
    errors=$((errors + 1))
  fi
}

echo "=== Score tests ==="
mkdir -p reports
rm -f reports/stats.dat reports/summary.txt reports/category_stats.txt reports/trend.dat
test_score "500" "hello world" "1" "non-empty response"
test_score "100" "" "0" "empty response"
test_score "0" "a" "1" "single char"
test_score "9999" "x" "1" "high latency"

echo ""
echo "--- Category tests ---"
test_score "500" "code review" "1" "coding category" "coding"
test_score "500" "Paris is capital" "1" "knowledge category" "knowledge"
test_score "500" "say hello" "1" "instruction category" "instruction"

echo ""
echo "--- Trend file check ---"
if [[ -f reports/trend.dat ]]; then
  echo "  PASS: trend file created"
else
  echo "  FAIL: trend file not created"
  errors=$((errors + 1))
fi

if [[ -f reports/category_stats.txt ]]; then
  echo "  PASS: category stats created"
  grep -q "coding" reports/category_stats.txt && echo "  PASS: coding category found" || echo "  WARN: coding category not in stats"
else
  echo "  FAIL: category stats not created"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL SCORE TESTS PASSED"
else echo "$errors SCORE TEST(S) FAILED"; fi
exit "$errors"
