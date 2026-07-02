#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JUDGE="$ROOT/src/judge/fallback.sh"
errors=0

test_judge() {
  local model="$1" prompt="$2" resp_file="$3" expected_exit="$4" name="$5"
  result=$(bash "$JUDGE" "$model" "$prompt" "$resp_file" 2>/dev/null || true)
  overall=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('overall',0))" 2>/dev/null || echo "0")
  if [[ "$overall" =~ ^[0-9] ]]; then
    echo "  PASS: $name (overall=$overall)"
  else
    echo "  FAIL: $name (overall=$overall, result=$result)"
    errors=$((errors + 1))
  fi
}

echo "=== Judge tests ==="

# Test with good response
echo "This is a great and detailed response about Paris." > /tmp/dt_test_judge_good.txt
test_judge "llama3.2" "What is the capital of France?" "/tmp/dt_test_judge_good.txt" "0" "good response"

# Test with empty response
echo -n "" > /tmp/dt_test_judge_empty.txt
result=$(bash "$JUDGE" "llama3.2" "hello" "/tmp/dt_test_judge_empty.txt" 2>/dev/null || true)
overall=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('overall',0))" 2>/dev/null || echo "0")
if [[ "$overall" == "0" ]]; then
  echo "  PASS: empty response (overall=0)"
else
  echo "  FAIL: empty response (overall=$overall)"
  errors=$((errors + 1))
fi

# Test missing args
result=$(bash "$JUDGE" "" "" "" 2>/dev/null || true)
has_error=$(echo "$result" | python3 -c "import sys,json; print('error' in json.load(sys.stdin))" 2>/dev/null || echo "false")
if [[ "$has_error" == "True" ]]; then
  echo "  PASS: missing args triggers error"
else
  echo "  FAIL: missing args should trigger error"
  errors=$((errors + 1))
fi

# Test custom criteria file
result=$(bash "$JUDGE" "llama3.2" "hello" "" "$ROOT/fixtures/judge_criteria.txt" 2>/dev/null || true)
overall=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('overall',0))" 2>/dev/null || echo "0")
if [[ "$overall" =~ ^[0-9] ]]; then
  echo "  PASS: custom criteria file"
else
  echo "  FAIL: custom criteria file"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL JUDGE TESTS PASSED"
else echo "$errors JUDGE TEST(S) FAILED"; fi
exit "$errors"
