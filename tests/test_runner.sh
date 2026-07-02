#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/src/runner/fallback.sh"
errors=0

echo "=== Runner tests ==="

# Test missing fixture
result=$(bash "$RUNNER" 2>&1 || true)
if echo "$result" | grep -q "Usage"; then
  echo "  PASS: missing fixture shows usage"
else
  echo "  FAIL: missing fixture should show usage"
  errors=$((errors + 1))
fi

# Test with fixture
result=$(bash "$RUNNER" "$ROOT/fixtures/eval_prompts.txt" 2>&1 || true)
if echo "$result" | grep -q "Parallel runner"; then
  echo "  PASS: parallel runner runs with fixture"
else
  echo "  FAIL: runner should run with fixture"
  errors=$((errors + 1))
fi

# Test output contains result line
if echo "$result" | grep -q "# Results"; then
  echo "  PASS: output has results line"
else
  echo "  FAIL: output should have results line"
  errors=$((errors + 1))
fi

# Test output contains pass_rate JSON
if echo "$result" | grep -q "pass_rate"; then
  echo "  PASS: output contains pass_rate"
else
  echo "  FAIL: output should contain pass_rate"
  errors=$((errors + 1))
fi

# Test runner.py --help
if command -v python3 &>/dev/null; then
  help_out=$(python3 "$ROOT/src/runner/runner.py" --help 2>&1 || true)
  if echo "$help_out" | grep -qi "parallel"; then
    echo "  PASS: runner.py --help works"
  else
    echo "  FAIL: runner.py --help should work"
    errors=$((errors + 1))
  fi
fi

# Test jobs flag documented
if echo "$help_out" | grep -q "jobs"; then
  echo "  PASS: --jobs flag documented"
else
  echo "  FAIL: --jobs flag should be documented"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL RUNNER TESTS PASSED"
else echo "$errors RUNNER TEST(S) FAILED"; fi
exit "$errors"
