#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/deepiri-tombstone"
errors=0

test_cli() {
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

echo "=== CLI dispatch tests ==="

test_cli "version prints the VERSION file" "$(cat "$ROOT/VERSION")" "$CLI" version
test_cli "--version is accepted" "deepiri-tombstone" "$CLI" --version
test_cli "-V is accepted" "deepiri-tombstone" "$CLI" -V

test_cli "help lists core commands" "ask <model> <prompt>" "$CLI" help
test_cli "help lists the version command" "print the harness version" "$CLI" help
test_cli "help advertises fast parallel eval" "keep-alive" "$CLI" help
test_cli "unknown command is rejected" "Unknown command" "$CLI" definitely-not-a-command

# eval defaults to the parallel runner; --classic keeps the B core.
if grep -q 'exec "\$ROOT/bin/runner"' "$CLI" && grep -q -- '--classic' "$CLI"; then
  echo "  PASS: eval defaults to runner with --classic escape hatch"
else
  echo "  FAIL: eval should default to runner and support --classic"
  errors=$((errors + 1))
fi

# The rag dispatch must forward the context as its own argument rather than
# repeating the answer, otherwise faithfulness compares the answer to itself.
rag_line=$(grep -n 'bin/rag' "$CLI")
if echo "$rag_line" | grep -q '"\$ARG3" "\$ARG3"'; then
  echo "  FAIL: rag dispatch still passes ARG3 twice"
  errors=$((errors + 1))
else
  echo "  PASS: rag dispatch does not duplicate ARG3"
fi

if echo "$rag_line" | grep -q '\${5:-}'; then
  echo "  PASS: rag dispatch forwards the 5th argument as context"
else
  echo "  FAIL: rag dispatch does not forward the 5th argument"
  errors=$((errors + 1))
fi

# Every command advertised by help should have a dispatch arm.
for cmd in ping ask eval judge mutate bench synth dashboard trace rag jury \
           replay runner checkpoint stats guard api notify registry chat \
           cost export version help models warm summary doctor; do
  if grep -qE "^  ([a-z|_-]*\|)?${cmd}[|)]" "$CLI"; then
    echo "  PASS: dispatch arm exists for '$cmd'"
  else
    echo "  FAIL: no dispatch arm for '$cmd'"
    errors=$((errors + 1))
  fi
done

test_cli "help lists doctor" "doctor" "$CLI" help

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL CLI TESTS PASSED"
else echo "$errors CLI TEST(S) FAILED"; fi
exit "$errors"
