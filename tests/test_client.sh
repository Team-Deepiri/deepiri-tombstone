#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "=== Ollama client / cache / ledger batch tests ==="

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; errors=$((errors + 1)); }

# Cache round-trip without a live Ollama
export DEEPIRI_TOMBSTONE_CACHE_DIR="$TMP/cache"
unset DEEPIRI_TOMBSTONE_NO_CACHE || true

python3 - "$ROOT" <<'PY' || { fail "cache round-trip"; exit 1; }
import os, sys, tempfile
sys.path.insert(0, os.path.join(sys.argv[1], "src", "common"))
import ollama_client as oc

assert oc.cache_get("m", "hello") is None
oc.cache_put("m", "hello", "world")
assert oc.cache_get("m", "hello") == "world"
assert oc.cache_get("m", "other") is None
stats = oc.cache_stats()
assert stats["entries"] >= 1
print("ok")
PY
pass "cache put/get round-trip"

# NO_CACHE disables reads/writes
export DEEPIRI_TOMBSTONE_NO_CACHE=1
python3 - "$ROOT" <<'PY' || { fail "NO_CACHE"; exit 1; }
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "src", "common"))
import ollama_client as oc
oc.cache_put("m", "nocache", "x")
assert oc.cache_get("m", "nocache") is None
print("ok")
PY
pass "DEEPIRI_TOMBSTONE_NO_CACHE disables cache"
unset DEEPIRI_TOMBSTONE_NO_CACHE

# Ledger batch append + pipe-in-prompt survival
python3 - "$ROOT" "$TMP" <<'PY' || { fail "ledger batch"; exit 1; }
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "src", "common"))
import ledger

path = os.path.join(sys.argv[2], "audit.ledger")
n = ledger.append_batch(path, [
    {"run_id": "r1", "model": "m", "prompt": "a|b|c", "response": "yes",
     "latency_ms": 12, "status": "PASS"},
    ("r2", "m", "plain", "no", 34, "FAIL"),
])
assert n == 2
rows = ledger.load_ledger(path)
assert len(rows) == 2
assert rows[0]["prompt"] == "a|b|c"
assert rows[0]["latency_ms"] == "12"
assert rows[0]["status"] == "PASS"
assert rows[1]["status"] == "FAIL"
stats_path = os.path.join(sys.argv[2], "stats.dat")
ledger.append_stats_batch(stats_path, [(12, 3, 1), {"latency_ms": 34, "length": 2, "pass": 0}])
stats = ledger.load_stats(stats_path)
assert len(stats) == 2
print("ok")
PY
pass "ledger append_batch preserves piped prompts"

# runner --help documents cache and ledger
help_out=$(python3 "$ROOT/src/runner/runner.py" --help 2>&1 || true)
if echo "$help_out" | grep -q -- "--ledger"; then
  pass "runner --ledger documented"
else
  fail "runner --ledger documented"
fi
if echo "$help_out" | grep -q -- "--no-cache"; then
  pass "runner --no-cache documented"
else
  fail "runner --no-cache documented"
fi

# CLI eval help / classic flag wiring
help_out=$("$ROOT/deepiri-tombstone" eval --help 2>&1 || true)
if echo "$help_out" | grep -q "classic"; then
  pass "eval --help mentions classic"
else
  fail "eval --help mentions classic"
fi
cli_help=$("$ROOT/deepiri-tombstone" help 2>&1 || true)
if echo "$cli_help" | grep -q "keep-alive"; then
  pass "help advertises fast parallel eval"
else
  fail "help advertises fast parallel eval"
fi

# Dispatch: eval without --classic should invoke runner, not core
# (dry-check by grepping the dispatcher script)
if grep -q 'exec "\$ROOT/bin/runner"' "$ROOT/deepiri-tombstone"; then
  pass "eval default path execs runner"
else
  fail "eval default path execs runner"
fi
if grep -q -- '--classic' "$ROOT/deepiri-tombstone"; then
  pass "eval supports --classic"
else
  fail "eval supports --classic"
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL CLIENT/CACHE TESTS PASSED"
else echo "$errors CLIENT/CACHE TEST(S) FAILED"; fi
exit "$errors"
