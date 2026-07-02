#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JURY="$ROOT/src/jury/fallback.sh"
JURY_PY="$ROOT/src/jury/jury.py"
errors=0

echo "=== Jury tests ==="

# Python syntax check
if python3 -c "import py_compile; py_compile.compile('$JURY_PY', doraise=True)" 2>/dev/null; then
  echo "  PASS: jury.py syntax OK"
else
  echo "  FAIL: jury.py syntax error"
  errors=$((errors + 1))
fi

# Test missing args
result=$(bash "$JURY" 2>&1 || true)
if echo "$result" | grep -qi "usage"; then
  echo "  PASS: missing args shows usage"
else
  echo "  FAIL: missing args should show usage (got: $result)"
  errors=$((errors + 1))
fi

# Test empty response
result=$(bash "$JURY" "hello" "" 2>&1 || true)
if echo "$result" | grep -qi "usage"; then
  echo "  PASS: empty response shows usage"
else
  echo "  FAIL: empty response should show usage (got: $result)"
  errors=$((errors + 1))
fi

# Test single juror with long response (31 chars -> score=2)
result=$(bash "$JURY" "What is capital?" "Paris is the capital of France." "llama3.2" 2>/dev/null || true)
overall=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('overall',0))" 2>/dev/null || echo "0")
if [[ "$overall" == "2" ]]; then
  echo "  PASS: single juror - long response (overall=$overall)"
else
  echo "  FAIL: single juror - long response (overall=$overall, expected=2)"
  errors=$((errors + 1))
fi

# Test single juror with short response (2 chars -> score=1)
result=$(bash "$JURY" "Hello" "Hi" "llama3.2" 2>/dev/null || true)
overall=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('overall',0))" 2>/dev/null || echo "0")
if [[ "$overall" == "1" ]]; then
  echo "  PASS: single juror - short response (overall=$overall)"
else
  echo "  FAIL: single juror - short response (overall=$overall, expected=1)"
  errors=$((errors + 1))
fi

# Test multiple jurors
result=$(bash "$JURY" "What is Python?" "Python is a programming language." "llama3.2" "mistral" 2>/dev/null || true)
overall=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('overall',0))" 2>/dev/null || echo "0")
jurors=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('jurors',0))" 2>/dev/null || echo "0")
if [[ "$overall" == "2" && "$jurors" == "2" ]]; then
  echo "  PASS: multiple jurors - 2 jurors (overall=$overall, jurors=$jurors)"
else
  echo "  FAIL: multiple jurors - 2 jurors (overall=$overall, jurors=$jurors)"
  errors=$((errors + 1))
fi

# Test three jurors
result=$(bash "$JURY" "Hey" "ok" "llama3.2" "mistral" "gemma" 2>/dev/null || true)
overall=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('overall',0))" 2>/dev/null || echo "0")
jurors=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('jurors',0))" 2>/dev/null || echo "0")
if [[ "$overall" == "1" && "$jurors" == "3" ]]; then
  echo "  PASS: three jurors (overall=$overall, jurors=$jurors)"
else
  echo "  FAIL: three jurors (overall=$overall, jurors=$jurors)"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL JURY TESTS PASSED"
else echo "$errors JURY TEST(S) FAILED"; fi
exit "$errors"
