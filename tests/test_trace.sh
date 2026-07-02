#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TRACE="$ROOT/src/trace/trace.py"
errors=0

echo "=== Trace tests ==="

if command -v python3 &>/dev/null; then
  # Test start trace
  trace_id=$(python3 "$TRACE" start -o /tmp/dt_test_trace.json 2>&1 || true)
  if [[ -n "$trace_id" && ${#trace_id} -ge 6 ]]; then
    echo "  PASS: trace started (id=$trace_id)"
  else
    echo "  FAIL: trace should start with an ID"
    errors=$((errors + 1))
  fi

  if [[ -f /tmp/dt_test_trace.json ]]; then
    size=$(wc -c < /tmp/dt_test_trace.json)
    if [[ "$size" -gt 50 ]]; then
      echo "  PASS: trace file is $size bytes"
    else
      echo "  FAIL: trace file too small ($size bytes)"
      errors=$((errors + 1))
    fi
  else
    echo "  FAIL: trace file not created"
    errors=$((errors + 1))
  fi

  # Test view trace
  view_out=$(python3 "$TRACE" view /tmp/dt_test_trace.json 2>&1 || true)
  if echo "$view_out" | grep -q "Trace:"; then
    echo "  PASS: trace view shows trace info"
  else
    echo "  FAIL: trace view should show trace info"
    errors=$((errors + 1))
  fi

  # Test with --help
  help_out=$(python3 "$TRACE" --help 2>&1 || true)
  if echo "$help_out" | grep -q "tracing"; then
    echo "  PASS: --help works"
  else
    echo "  FAIL: --help should work"
    errors=$((errors + 1))
  fi
else
  echo "  SKIP: python3 not available"
fi

rm -f /tmp/dt_test_trace.json

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL TRACE TESTS PASSED"
else echo "$errors TRACE TEST(S) FAILED"; fi
exit "$errors"
