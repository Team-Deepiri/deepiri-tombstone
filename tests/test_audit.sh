#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

test_audit() {
  local input="$1" expected_status="$2" name="$3"
  rm -f reports/audit.ledger
  result=$(echo "$input" | bash "$ROOT/src/audit/fallback.sh" 2>/dev/null || true)
  if echo "$result" | grep -q "$expected_status"; then
    echo "  PASS: $name"
  else
    echo "  FAIL: $name (expected '$expected_status', got '$result')"
    errors=$((errors + 1))
  fi
}

echo "=== Audit tests ==="
mkdir -p reports
test_audit "run-001|model|prompt|response|1234|PASS" "AUDIT OK" "basic pass"
test_audit "run-002|model|prompt|response|5678|FAIL" "AUDIT OK" "basic fail"
test_audit "run-003|model|prompt with|pipe|response|9999|PASS" "AUDIT OK" "prompt with pipe"
test_audit "run-004|model|||0|PASS" "AUDIT OK" "empty fields"
test_audit "run-005|test-model|hello world|ok|100|PASS" "AUDIT OK" "realistic data"

echo ""
echo "--- JSON mode tests ---"
export DEEPIRI_TOMBSTONE_OUTPUT=json
rm -f reports/audit.ledger
result=$(echo "run-json|test|json-prompt|json-response|500|PASS" | bash "$ROOT/src/audit/fallback.sh" 2>/dev/null || true)
if echo "$result" | grep -q "AUDIT OK"; then
  echo "  PASS: json mode audit"
else
  echo "  FAIL: json mode audit ($result)"
  errors=$((errors + 1))
fi
if grep -q "run_id" reports/audit.ledger 2>/dev/null; then
  echo "  PASS: json ledger format"
else
  echo "  FAIL: json ledger format"
  errors=$((errors + 1))
fi
export DEEPIRI_TOMBSTONE_OUTPUT=text

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL AUDIT TESTS PASSED"
else echo "$errors AUDIT TEST(S) FAILED"; fi
exit "$errors"
