#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYNTH="$ROOT/src/synth/fallback.sh"
errors=0

echo "=== Synthetic generator tests ==="

# Test missing args
result=$(bash "$SYNTH" 2>&1 || true)
if echo "$result" | grep -q "Usage"; then
  echo "  PASS: missing args shows usage"
else
  echo "  FAIL: missing args should show usage"
  errors=$((errors + 1))
fi

# Test with eval prompts fixture
result=$(bash "$SYNTH" "$ROOT/fixtures/eval_prompts.txt" 3 2>/dev/null || true)
lines=$(echo "$result" | grep -v '^#' | grep -c . || true)
if [[ "$lines" -ge 20 ]]; then
  echo "  PASS: generated $lines lines from eval fixture"
else
  echo "  FAIL: expected >=20 lines, got $lines"
  errors=$((errors + 1))
fi

# Test output contains source prompts
if echo "$result" | grep -q "2+2"; then
  echo "  PASS: output contains original prompts"
else
  echo "  FAIL: output should contain original prompts"
  errors=$((errors + 1))
fi

# Test PROMPT|KEYWORD format
has_pipe=$(echo "$result" | grep -v '^#' | head -3 | grep -c '|' || true)
if [[ "$has_pipe" -ge 1 ]]; then
  echo "  PASS: output uses PROMPT|KEYWORD format"
else
  echo "  FAIL: output should use PROMPT|KEYWORD format"
  errors=$((errors + 1))
fi

# Test with adversarial prompts fixture
result=$(bash "$SYNTH" "$ROOT/fixtures/adversarial_prompts.txt" 2 2>/dev/null || true)
lines=$(echo "$result" | grep -v '^#' | grep -c . || true)
if [[ "$lines" -ge 20 ]]; then
  echo "  PASS: generated $lines lines from adversarial fixture"
else
  echo "  FAIL: expected >=20 lines from adversarial fixture, got $lines"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL SYNTH TESTS PASSED"
else echo "$errors SYNTH TEST(S) FAILED"; fi
exit "$errors"
