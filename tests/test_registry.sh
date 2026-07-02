#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

echo "=== Model Registry tests ==="

# --help output
if python3 "$ROOT/src/models/registry.py" --help 2>&1 | grep -q "Model registry management"; then
  echo "  PASS: --help shows description"
else
  echo "  FAIL: --help"
  errors=$((errors + 1))
fi

# list action (no config file needed, uses defaults)
output=$(python3 "$ROOT/src/models/registry.py" list 2>/dev/null)
if echo "$output" | grep -q "llama3.2"; then
  echo "  PASS: list shows models"
else
  echo "  FAIL: list"
  errors=$((errors + 1))
fi

# list with tag filter
output=$(python3 "$ROOT/src/models/registry.py" list --tag code 2>/dev/null)
if echo "$output" | grep -q "codellama"; then
  echo "  PASS: list --tag code"
else
  echo "  FAIL: list --tag code"
  errors=$((errors + 1))
fi

# get existing model
output=$(python3 "$ROOT/src/models/registry.py" get llama3.2 2>/dev/null)
if echo "$output" | grep -q "provider"; then
  echo "  PASS: get existing model"
else
  echo "  FAIL: get existing model"
  errors=$((errors + 1))
fi

# get nonexistent model falls back to default
output=$(python3 "$ROOT/src/models/registry.py" get nonexistent 2>/dev/null)
if echo "$output" | grep -q "provider"; then
  echo "  PASS: get fallback to default"
else
  echo "  FAIL: get fallback"
  errors=$((errors + 1))
fi

# path action
output=$(python3 "$ROOT/src/models/registry.py" path 2>/dev/null)
if echo "$output" | grep -q "models.json"; then
  echo "  PASS: path shows config file path"
else
  echo "  FAIL: path"
  errors=$((errors + 1))
fi

# add action requires name
output=$(python3 "$ROOT/src/models/registry.py" add 2>&1 || true)
if echo "$output" | grep -q "ERROR.*model_name"; then
  echo "  PASS: add without name shows error"
else
  echo "  FAIL: add without name"
  errors=$((errors + 1))
fi

# get without name shows error
output=$(python3 "$ROOT/src/models/registry.py" get 2>&1 || true)
if echo "$output" | grep -q "ERROR.*model_name"; then
  echo "  PASS: get without name shows error"
else
  echo "  FAIL: get without name"
  errors=$((errors + 1))
fi

# init creates config
tmpdir=$(mktemp -d)
trap "rm -rf '$tmpdir'" EXIT
output=$(python3 "$ROOT/src/models/registry.py" -c "$tmpdir/models.json" init 2>&1 >/dev/null)
if [[ -f "$tmpdir/models.json" ]]; then
  echo "  PASS: init creates config file"
else
  echo "  FAIL: init"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL REGISTRY TESTS PASSED"
else echo "$errors REGISTRY TEST(S) FAILED"; fi
exit "$errors"
