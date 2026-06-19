#!/usr/bin/env bash
# Run all unit tests
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
errors=0

echo "=== deepiri-tombstone unit tests ==="
echo ""

for test in tests/test_*.sh; do
  name=$(basename "$test" .sh)
  echo "--- $name ---"
  if bash "$test"; then
    echo ""
  else
    errors=$((errors + 1))
  fi
done

if [[ "$errors" -eq 0 ]]; then
  echo "ALL UNIT TESTS PASSED"
else
  echo "$errors UNIT TEST SUITE(S) FAILED"
fi
exit "$errors"
