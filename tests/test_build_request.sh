#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILDER="$ROOT/scripts/build_request_fallback.sh"
errors=0

test_request() {
  local model="$1" prompt="$2" expected="$3" name="$4"
  result=$(bash "$BUILDER" "$model" "$prompt" 2>/dev/null || true)
  if echo "$result" | grep -q "$expected"; then
    echo "  PASS: $name"
  else
    echo "  FAIL: $name (expected '$expected' in output, got '$result')"
    errors=$((errors + 1))
  fi
}

echo "=== Build request tests ==="
test_request "llama3.2" "hello" '"model": "llama3.2"' "basic request uses given model"
test_request "llama3.2" "hello" '"prompt": "hello"' "basic request includes prompt"
test_request "llama3.2" "hello" '"stream": false' "stream is disabled"
test_request "llama3.2" "" "prompt is required" "empty prompt rejected"
test_request "llama3.2" "hello \"world\"" 'hello' "prompt with quoted words"
test_request "" "hello" 'llama3.2' "empty model defaults to llama3.2"

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL BUILD REQUEST TESTS PASSED"
else echo "$errors BUILD REQUEST TEST(S) FAILED"; fi
exit "$errors"
