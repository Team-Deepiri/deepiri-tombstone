#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; errors=$((errors + 1)); }

echo "=== paths helpers ==="

python3 - "$ROOT" <<'PY' || { fail "paths module"; exit 1; }
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "src", "common"))
import paths

root = paths.repo_root(os.path.join(sys.argv[1], "src", "common", "paths.py"))
assert os.path.isfile(os.path.join(root, "VERSION")), root
ver = paths.read_version(os.path.join(sys.argv[1], "src", "doctor", "doctor.py"))
assert ver and ver != "unknown", ver
d = paths.ensure_common_path(os.path.join(sys.argv[1], "src", "runner", "runner.py"))
assert d and os.path.isfile(os.path.join(d, "paths.py"))
print(ver)
PY
pass "repo_root / read_version / ensure_common_path"

# doctor uses read_version
if grep -q "read_version" "$ROOT/src/doctor/doctor.py" && grep -q "read_version" "$ROOT/src/api/server.py"; then
  pass "doctor and api share read_version"
else
  fail "doctor and api share read_version"
fi

if grep -q "ensure_common_path" "$ROOT/src/runner/runner.py" && [[ -f "$ROOT/src/common/paths.py" ]]; then
  pass "runner boots via paths.py"
else
  fail "runner boots via paths.py"
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL PATHS TESTS PASSED"
else echo "$errors PATHS TEST(S) FAILED"; fi
exit "$errors"
