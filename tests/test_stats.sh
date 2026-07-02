#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATS="$ROOT/src/stats/fallback.sh"
errors=0
echo "=== Stats tests ==="
# Missing file
result=$(bash "$STATS" "/nonexistent" 2>&1 || true)
if echo "$result" | grep -q "No stats file"; then
  echo "  PASS: missing file handled"
else
  echo "  FAIL: missing file should be handled"
  errors=$((errors + 1))
fi
# Create test stats
mkdir -p "$ROOT/reports"
cat > /tmp/dt_stats_test.dat << 'EOF'
500 100 1
300 50 1
1000 200 0
200 75 1
150 60 1
EOF
result=$(bash "$STATS" "/tmp/dt_stats_test.dat" 2>/dev/null || true)
n=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('n',0))" 2>/dev/null || echo "0")
if [[ "$n" -eq 5 ]]; then
  echo "  PASS: parsed $n entries"
else
  echo "  FAIL: expected 5 entries, got $n"
  errors=$((errors + 1))
fi
pass_rate=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pass_rate',0))" 2>/dev/null || echo "0")
if [[ "$pass_rate" -eq 80 ]]; then
  echo "  PASS: pass_rate=$pass_rate"
else
  echo "  FAIL: expected pass_rate=80, got $pass_rate"
  errors=$((errors + 1))
fi
# Test python version with --ci
if command -v python3 &>/dev/null; then
  ci_out=$(python3 "$ROOT/src/stats/stats.py" -f /tmp/dt_stats_test.dat --ci 2>/dev/null || true)
  has_ci=$(echo "$ci_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ci_lower' in d.get('latency',{}))" 2>/dev/null || echo "false")
  if [[ "$has_ci" == "True" ]]; then
    echo "  PASS: bootstrap CI computed"
  else
    echo "  FAIL: bootstrap CI missing"
    errors=$((errors + 1))
  fi
fi
echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL STATS TESTS PASSED"
else echo "$errors STATS TEST(S) FAILED"; fi
exit "$errors"
