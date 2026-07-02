#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH="$ROOT/src/bench/fallback.sh"
errors=0

echo "=== Benchmark tests ==="

# Test missing args
result=$(bash "$BENCH" 2>&1 || true)
if echo "$result" | grep -q "Usage"; then
  echo "  PASS: missing args shows usage"
else
  echo "  FAIL: missing args should show usage"
  errors=$((errors + 1))
fi

# Test with fixture but no models
result=$(bash "$BENCH" "$ROOT/fixtures/eval_prompts.txt" 2>&1 || true)
if echo "$result" | grep -q "Usage"; then
  echo "  PASS: missing models shows usage"
else
  echo "  FAIL: missing models should show usage"
  errors=$((errors + 1))
fi

# Test output format with known fixture
result=$(bash "$BENCH" "$ROOT/fixtures/eval_prompts.txt" "test-model" 2>/dev/null || true)
if echo "$result" | grep -q "pass_rate"; then
  echo "  PASS: output contains pass_rate"
else
  echo "  FAIL: output should contain pass_rate"
  errors=$((errors + 1))
fi

# Test header lines
if echo "$result" | grep -q "^# Benchmark results"; then
  echo "  PASS: output has header"
else
  echo "  FAIL: output should have header"
  errors=$((errors + 1))
fi

# Test the bench.py --help (if python3 available)
if command -v python3 &>/dev/null; then
  help_out=$(python3 "$ROOT/src/bench/bench.py" --help 2>&1 || true)
  if echo "$help_out" | grep -q "multi-model"; then
    echo "  PASS: bench.py --help works"
  else
    echo "  FAIL: bench.py --help should work"
    errors=$((errors + 1))
  fi
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL BENCH TESTS PASSED"
else echo "$errors BENCH TEST(S) FAILED"; fi
exit "$errors"
