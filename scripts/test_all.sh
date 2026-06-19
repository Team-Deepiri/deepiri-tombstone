#!/usr/bin/env bash
# Run all tests and checks
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
errors=0

echo "=== deepiri-tombstone test suite ==="
echo ""

echo "--- Fixture validation ---"
bash scripts/validate_fixtures.sh fixtures/eval_prompts.txt || errors=$((errors + 1))
bash scripts/validate_fixtures.sh fixtures/edge_cases.txt || errors=$((errors + 1))
bash scripts/validate_fixtures.sh fixtures/benchmark_prompts.txt || errors=$((errors + 1))
bash scripts/validate_fixtures.sh fixtures/stress_prompts.txt || errors=$((errors + 1))

echo ""
echo "--- Shell syntax ---"
for f in scripts/*.sh; do
  bash -n "$f" || { echo "  FAIL: $f"; errors=$((errors + 1)); }
done

echo ""
echo "--- Perl syntax ---"
perl -c perl/http_fallback.pl > /dev/null || errors=$((errors + 1))

echo ""
echo "--- AWK parse test ---"
echo '{"response":"hello"}' | awk -f awk/parse_response.awk | grep -q "hello" || {
  echo "  FAIL: AWK parse basic"
  errors=$((errors + 1))
}

echo ""
echo "--- Component tests ---"
bash scripts/test_component.sh all || errors=$((errors + 1))

echo ""
echo "--- Integration ---"
bash scripts/verify_all.sh || errors=$((errors + 1))

echo ""
if [[ "$errors" -eq 0 ]]; then
  echo "ALL TESTS PASSED"
else
  echo "$errors TEST(S) FAILED"
fi
exit "$errors"
