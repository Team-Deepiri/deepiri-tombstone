#!/usr/bin/env bash
# Test the AWK parser with various JSON inputs
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

test_parse() {
  local input="$1" expected="$2" name="$3"
  result=$(echo "$input" | awk -f "$ROOT/awk/parse_response.awk" 2>/dev/null || true)
  if [[ "$result" == "$expected" ]]; then
    echo "  PASS: $name"
  else
    echo "  FAIL: $name (expected '$expected', got '$result')"
    errors=$((errors + 1))
  fi
}

echo "=== AWK parser tests ==="
test_parse '{"response":"hello"}' "hello" "basic"
test_parse '{"response":"hello world"}' "hello world" "with space"
test_parse '{"response":"line1\nline2"}' "$(printf "line1\nline2")" "newline escape"
test_parse '{"response":"tab\there"}' "$(printf "tab\there")" "tab escape"
test_parse '{"response":"quote\"here"}' 'quote"here' "quote escape"
test_parse '{"response":"back\\slash"}' 'back\slash' "backslash escape"
test_parse '{"response":""}' "" "empty string"
test_parse '{"response":"hello","done":true}' "hello" "with extra fields"
test_parse '{"response":"café"}' "café" "unicode"

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL AWK TESTS PASSED"
else echo "$errors AWK TEST(S) FAILED"; fi
exit "$errors"
