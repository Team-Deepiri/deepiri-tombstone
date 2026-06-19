#!/usr/bin/env bash
# Verify all shell scripts with shellcheck-compatible syntax checking
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
errors=0

echo "=== Shell script verification ==="

for f in scripts/*.sh tests/*.sh; do
  if [[ ! -f "$f" ]]; then continue; fi
  name=$(basename "$f")
  echo -n "  $name: "
  if bash -n "$f" 2>/dev/null; then
    echo "syntax OK"
  else
    echo "SYNTAX ERROR"
    errors=$((errors + 1))
  fi
  # Check for common issues
  if grep -qP '\$\[[^]]+\]' "$f" 2>/dev/null; then
    echo "    WARNING: uses legacy $[] arithmetic"
  fi
done

echo ""
if [[ "$errors" -eq 0 ]]; then echo "All scripts valid"
else echo "$errors script(s) have syntax errors"; fi
exit "$errors"
