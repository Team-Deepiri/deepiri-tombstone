#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

test_http() {
  local model="$1" prompt="$2" expected="$3" name="$4"
  result=$(perl -c "$ROOT/src/transport/http_fallback.pl" 2>&1 || true)
  if echo "$result" | grep -q "$expected"; then
    echo "  PASS: $name"
  else
    echo "  FAIL: $name ($result)"
    errors=$((errors + 1))
  fi
}

echo "=== HTTP Fallback tests ==="
test_http "test" "hello" "syntax OK" "perl syntax check"

echo ""
echo "--- Usage test ---"
usage=$(perl "$ROOT/src/transport/http_fallback.pl" 2>&1 || true)
if echo "$usage" | grep -qi "usage"; then
  echo "  PASS: usage displayed when no args"
else
  echo "  FAIL: no usage message ($usage)"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL HTTP FALLBACK TESTS PASSED"
else echo "$errors HTTP FALLBACK TEST(S) FAILED"; fi
exit "$errors"
