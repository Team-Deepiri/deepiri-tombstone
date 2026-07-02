#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

test_cost() {
  local desc="$1" expected="$2"
  shift 2
  local output
  output=$("$@" 2>&1 || true)
  if echo "$output" | grep -q "$expected"; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc (expected pattern '$expected')"
    echo "    output: $(echo "$output" | head -c 250)"
    errors=$((errors + 1))
  fi
}

echo "=== Cost tests ==="

test_cost "estimate action" "total_cost_usd" python3 "$ROOT/src/cost/cost.py" estimate -m llama3.2 --prompt "Hello" --response "World"

test_cost "models action lists models" "llama3.2" python3 "$ROOT/src/cost/cost.py" models

test_cost "models action shows pricing" "input_per_1k" python3 "$ROOT/src/cost/cost.py" models

test_cost "missing prompt defaults" "total_tokens" python3 "$ROOT/src/cost/cost.py" estimate -m gpt-4

test_cost "ledger action reads file" "total_tokens" python3 "$ROOT/src/cost/cost.py" ledger -l "$ROOT/reports/audit.ledger"

test_cost "ledger with missing file" "No entries" python3 "$ROOT/src/cost/cost.py" ledger -l /tmp/nonexistent_ledger.dat

test_cost "no args shows usage" "usage:" python3 "$ROOT/src/cost/cost.py"

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL COST TESTS PASSED"
else echo "$errors COST TEST(S) FAILED"; fi
exit "$errors"
