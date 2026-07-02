#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

echo "=== API Server tests ==="

# --help output
if python3 "$ROOT/src/api/server.py" --help 2>&1 | grep -q "REST API server"; then
  echo "  PASS: --help shows description"
else
  echo "  FAIL: --help"
  errors=$((errors + 1))
fi

# --help mentions port
if python3 "$ROOT/src/api/server.py" --help 2>&1 | grep -q "\-\-port"; then
  echo "  PASS: --help shows --port"
else
  echo "  FAIL: --help missing --port"
  errors=$((errors + 1))
fi

# --help mentions host
if python3 "$ROOT/src/api/server.py" --help 2>&1 | grep -q "\-\-host"; then
  echo "  PASS: --help shows --host"
else
  echo "  FAIL: --help missing --host"
  errors=$((errors + 1))
fi

# invalid arg
output=$(python3 "$ROOT/src/api/server.py" --bogus 2>&1 || true)
if echo "$output" | grep -q "unrecognized"; then
  echo "  PASS: invalid arg rejected"
else
  echo "  FAIL: invalid arg"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL API TESTS PASSED"
else echo "$errors API TEST(S) FAILED"; fi
exit "$errors"
