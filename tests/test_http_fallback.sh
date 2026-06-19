#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FALLBACK="$ROOT/perl/http_fallback.pl"
errors=0

echo "=== HTTP fallback tests ==="

# No arguments — should print usage and die
result=$(perl "$FALLBACK" 2>&1 || true)
if echo "$result" | grep -qi "usage"; then
  echo "  PASS: no args shows usage"
else
  echo "  FAIL: no args (expected 'usage' in output, got '$result')"
  errors=$((errors + 1))
fi

# One argument — should print usage and die
result=$(perl "$FALLBACK" "test" 2>&1 || true)
if echo "$result" | grep -qi "usage"; then
  echo "  PASS: one arg shows usage"
else
  echo "  FAIL: one arg (expected 'usage' in output, got '$result')"
  errors=$((errors + 1))
fi

# Two arguments but unreachable host — should try curl and fail
result=$(DEEPIRI_TOMBSTONE_HOST="127.0.0.1:1" perl "$FALLBACK" "model" "hello" 2>&1 || true)
if echo "$result" | grep -qi "curl\|refused\|failed"; then
  echo "  PASS: unreachable host invokes curl"
else
  echo "  FAIL: unreachable host (expected curl/refused/failed, got '$result')"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL HTTP FALLBACK TESTS PASSED"
else echo "$errors HTTP FALLBACK TEST(S) FAILED"; fi
exit "$errors"
