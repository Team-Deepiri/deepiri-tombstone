#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOKENIZER="$ROOT/src/tokenize/fallback.sh"
errors=0

test_tokenize() {
  local input="$1" expected_words="$2" expected_budget="$3" name="$4"
  result=$(echo "$input" | bash "$TOKENIZER" 2>/dev/null || true)
  words=$(echo "$result" | awk '{print $2}')
  budget=$(echo "$result" | awk '{print $4}')
  if [[ "$words" == "$expected_words" && "$budget" == "$expected_budget" ]]; then
    echo "  PASS: $name"
  else
    echo "  FAIL: $name (expected words=$expected_words budget=$expected_budget, got '$result')"
    errors=$((errors + 1))
  fi
}

echo "=== Tokenizer tests ==="
test_tokenize "hello world" "2" "1" "two words"
test_tokenize "" "0" "1" "empty"
test_tokenize "hello" "1" "1" "one word"
test_tokenize "  hello  world  " "2" "1" "leading/trailing spaces"
test_tokenize "$(printf "hello\nworld")" "1" "1" "newline separated (reads first line only)"

long_input=$(printf 'word %.0s' {1..600})
test_tokenize "$long_input" "600" "0" "over budget (600 words)"

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL TOKENIZER TESTS PASSED"
else echo "$errors TOKENIZER TEST(S) FAILED"; fi
exit "$errors"
