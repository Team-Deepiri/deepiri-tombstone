#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PARSER="$ROOT/awk/parse_response.awk"
errors=0

test_parse() {
  local input="$1" expected="$2" name="$3"
  result=$(echo "$input" | awk -f "$PARSER" 2>/dev/null || true)
  if [[ "$result" == "$expected" ]]; then
    echo "  PASS: $name"
  else
    echo "  FAIL: $name (expected '$expected', got '$result')"
    errors=$((errors + 1))
  fi
}

echo "=== Parser tests (parse_response.awk) ==="
test_parse '{"response":"ok"}' "ok" "basic"
test_parse '{"response":"hello world"}' "hello world" "with space"
test_parse '{"response":"line1\nline2"}' "$(printf "line1\nline2")" "newline"
test_parse '{"response":"tab\there"}' "$(printf "tab\there")" "tab"
test_parse '{"response":"quote\"here"}' 'quote"here' "quote"
test_parse '{"response":"back\\slash"}' 'back\slash' "backslash"
test_parse '{"response":"café"}' "café" "unicode"
test_parse '{"response":""}' "" "empty string"
test_parse '{"response":"val","done":true}' "val" "extra fields"
test_parse '{"a":1}' "" "no response key"
test_parse '{}' "" "empty object"
test_parse 'garbage' "" "invalid json"

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL PARSER TESTS PASSED"
else echo "$errors PARSER TEST(S) FAILED"; fi
exit "$errors"
