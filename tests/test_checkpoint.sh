#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKPOINT="$ROOT/src/checkpoint/checkpoint.py"
errors=0

echo "=== Checkpoint tests ==="

if ! command -v python3 &>/dev/null; then
  echo "  SKIP: python3 not available"
  exit 0
fi

CP_FILE="/tmp/deepiri_test_checkpoint.json"
trap 'rm -f "$CP_FILE"' EXIT

# Test init
result=$(python3 "$CHECKPOINT" init -f "$ROOT/fixtures/eval_prompts.txt" -m test-model -c "$CP_FILE" 2>&1 || true)
if echo "$result" | grep -q "Checkpoint initialized"; then
  echo "  PASS: init creates checkpoint"
else
  echo "  FAIL: init should create checkpoint"
  errors=$((errors + 1))
fi
if [[ -f "$CP_FILE" ]]; then
  echo "  PASS: checkpoint file exists"
else
  echo "  FAIL: checkpoint file should exist"
  errors=$((errors + 1))
fi

# Test status
result=$(python3 "$CHECKPOINT" status -c "$CP_FILE" 2>&1 || true)
if echo "$result" | grep -q "Progress"; then
  echo "  PASS: status shows progress"
else
  echo "  FAIL: status should show progress"
  errors=$((errors + 1))
fi

# Test load
result=$(python3 "$CHECKPOINT" load -c "$CP_FILE" 2>&1 || true)
if echo "$result" | grep -q "Checkpoint loaded"; then
  echo "  PASS: load reads checkpoint"
else
  echo "  FAIL: load should read checkpoint"
  errors=$((errors + 1))
fi

# Test save
result=$(python3 "$CHECKPOINT" save -c "$CP_FILE" 2>&1 || true)
if echo "$result" | grep -q "Checkpoint saved"; then
  echo "  PASS: save persists checkpoint"
else
  echo "  FAIL: save should persist checkpoint"
  errors=$((errors + 1))
fi

# Test clear
result=$(python3 "$CHECKPOINT" clear -c "$CP_FILE" 2>&1 || true)
if echo "$result" | grep -q "Checkpoint cleared"; then
  echo "  PASS: clear removes checkpoint"
else
  echo "  FAIL: clear should remove checkpoint"
  errors=$((errors + 1))
fi
if [[ ! -f "$CP_FILE" ]]; then
  echo "  PASS: checkpoint file removed"
else
  echo "  FAIL: checkpoint file should be removed"
  errors=$((errors + 1))
fi

# Test status on missing checkpoint
result=$(python3 "$CHECKPOINT" status -c "$CP_FILE" 2>&1 || true)
if echo "$result" | grep -q "No checkpoint found"; then
  echo "  PASS: status on missing shows not found"
else
  echo "  FAIL: status on missing should show not found"
  errors=$((errors + 1))
fi

# Test --help
help_out=$(python3 "$CHECKPOINT" --help 2>&1 || true)
if echo "$help_out" | grep -q "checkpointing"; then
  echo "  PASS: checkpoint.py --help works"
else
  echo "  FAIL: checkpoint.py --help should work"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL CHECKPOINT TESTS PASSED"
else echo "$errors CHECKPOINT TEST(S) FAILED"; fi
exit "$errors"
