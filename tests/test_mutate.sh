#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MUTATE="$ROOT/src/mutate/fallback.sh"
errors=0

echo "=== Mutation tests ==="

# Test with adversarial fixture
result=$(bash "$MUTATE" "$ROOT/fixtures/adversarial_prompts.txt" 2>/dev/null || true)
lines=$(echo "$result" | grep -c -v '^#' || true)
if [[ "$lines" -ge 10 ]]; then
  echo "  PASS: generated $lines mutation lines from adversarial fixture"
else
  echo "  FAIL: expected >=10 lines, got $lines"
  errors=$((errors + 1))
fi

# Test missing fixture
result=$(bash "$MUTATE" "" 2>&1 || true)
if echo "$result" | grep -q "Usage"; then
  echo "  PASS: missing fixture shows usage"
else
  echo "  FAIL: missing fixture should show usage"
  errors=$((errors + 1))
fi

# Test with eval prompts fixture
result=$(bash "$MUTATE" "$ROOT/fixtures/eval_prompts.txt" 2>/dev/null || true)
lines=$(echo "$result" | grep -v '^#' | grep -c . || true)
if [[ "$lines" -ge 10 ]]; then
  echo "  PASS: generated $lines mutation lines from eval fixture"
else
  echo "  FAIL: expected >=10 lines, got $lines"
  errors=$((errors + 1))
fi

# Verify output format (PROMPT|KEYWORD)
result=$(bash "$MUTATE" "$ROOT/fixtures/eval_prompts.txt" 2>/dev/null || true)
has_pipe=$(echo "$result" | grep -v '^#' | head -1 | grep -c '|' || true)
if [[ "$has_pipe" -ge 1 ]]; then
  echo "  PASS: output uses PROMPT|KEYWORD format"
else
  echo "  FAIL: output should use PROMPT|KEYWORD format"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL MUTATION TESTS PASSED"
else echo "$errors MUTATION TEST(S) FAILED"; fi
exit "$errors"
