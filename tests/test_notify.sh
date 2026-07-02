#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

echo "=== Notify tests ==="

# --help output
if python3 "$ROOT/src/notify/notify.py" --help 2>&1 | grep -q "Send webhook notifications"; then
  echo "  PASS: --help shows description"
else
  echo "  FAIL: --help"
  errors=$((errors + 1))
fi

# missing args yields error
output=$(python3 "$ROOT/src/notify/notify.py" 2>&1 || true)
if echo "$output" | grep -q "required"; then
  echo "  PASS: missing args shows required"
else
  echo "  FAIL: missing args"
  errors=$((errors + 1))
fi

# invalid type yields error
output=$(python3 "$ROOT/src/notify/notify.py" invalid https://hook.example.com 2>&1 || true)
if echo "$output" | grep -q "invalid\|choose\|argument"; then
  echo "  PASS: invalid type rejected"
else
  echo "  FAIL: invalid type"
  errors=$((errors + 1))
fi

# --help shows type choices
if python3 "$ROOT/src/notify/notify.py" --help 2>&1 | grep -q "slack\|discord\|generic"; then
  echo "  PASS: --help shows webhook types"
else
  echo "  FAIL: --help missing types"
  errors=$((errors + 1))
fi

# --help shows optional flags
if python3 "$ROOT/src/notify/notify.py" --help 2>&1 | grep -q "\-f FILE"; then
  echo "  PASS: --help shows --file flag"
else
  echo "  FAIL: --help missing --file"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL NOTIFY TESTS PASSED"
else echo "$errors NOTIFY TEST(S) FAILED"; fi
exit "$errors"
