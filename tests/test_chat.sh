#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

test_chat() {
  local desc="$1" expected="$2"
  shift 2
  local output
  output=$("$@" 2>&1 || true)
  if echo "$output" | grep -q "$expected"; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc (expected pattern '$expected')"
    echo "    output: $(echo "$output" | head -c 200)"
    errors=$((errors + 1))
  fi
}

echo "=== Chat tests ==="

test_chat "--help shows usage" "usage:" python3 "$ROOT/src/chat/chat.py" --help

test_chat "--help via short flag" "usage:" python3 "$ROOT/src/chat/chat.py" -h

test_chat "file not found error" "ERROR: file not found" python3 "$ROOT/src/chat/chat.py" nonexistent.json

test_chat "--interactive --help shows turns" "turns" python3 "$ROOT/src/chat/chat.py" --interactive --help

test_chat "no args shows help" "usage:" python3 "$ROOT/src/chat/chat.py"

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL CHAT TESTS PASSED"
else echo "$errors CHAT TEST(S) FAILED"; fi
exit "$errors"
