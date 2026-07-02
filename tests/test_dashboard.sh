#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)" 
DASHBOARD="$ROOT/src/report/dashboard.py"
errors=0

echo "=== Dashboard tests ==="

# Create test stats
mkdir -p "$ROOT/reports"
cat > "$ROOT/reports/stats.dat" << 'EOF'
500 100 1 0
300 50 1 0
1000 200 0 1
200 75 1 0
EOF

# Create test audit ledger
cat > "$ROOT/reports/audit.ledger" << 'EOF'
run-001|llama3.2|What is 2+2?|4|500|PASS
run-002|llama3.2|Say YES|YES|300|PASS
run-003|llama3.2|Return JSON|fail|1000|FAIL
run-004|mistral|Capital of France|Paris|200|PASS
EOF

# Test with python3
if command -v python3 &>/dev/null; then
  result=$(python3 "$DASHBOARD" -o /tmp/dt_test_dashboard.html 2>&1 || true)
  if echo "$result" | grep -q "Dashboard written"; then
    echo "  PASS: dashboard generated"
  else
    echo "  FAIL: dashboard should generate"
    errors=$((errors + 1))
  fi

  if [[ -f /tmp/dt_test_dashboard.html ]]; then
    size=$(wc -c < /tmp/dt_test_dashboard.html)
    if [[ "$size" -gt 1000 ]]; then
      echo "  PASS: dashboard HTML is $size bytes"
    else
      echo "  FAIL: dashboard HTML too small ($size bytes)"
      errors=$((errors + 1))
    fi
    if grep -q "deepiri-tombstone" /tmp/dt_test_dashboard.html; then
      echo "  PASS: dashboard contains project name"
    else
      echo "  FAIL: dashboard missing project name"
      errors=$((errors + 1))
    fi
    if grep -q "PASS" /tmp/dt_test_dashboard.html; then
      echo "  PASS: dashboard contains PASS status"
    else
      echo "  FAIL: dashboard missing PASS status"
      errors=$((errors + 1))
    fi
  else
    echo "  FAIL: dashboard HTML file not created"
    errors=$((errors + 1))
  fi

  # Test with --help
  help_out=$(python3 "$DASHBOARD" --help 2>&1 || true)
  if echo "$help_out" | grep -q "dashboard"; then
    echo "  PASS: --help works"
  else
    echo "  FAIL: --help should work"
    errors=$((errors + 1))
  fi
else
  echo "  SKIP: python3 not available"
fi

# Cleanup
rm -f /tmp/dt_test_dashboard.html

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL DASHBOARD TESTS PASSED"
else echo "$errors DASHBOARD TEST(S) FAILED"; fi
exit "$errors"
