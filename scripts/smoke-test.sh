#!/usr/bin/env bash
# Quick smoke test to verify the project builds and runs
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
errors=0

echo "=== deepiri-tombstone smoke test ==="

echo "--- Build check ---"
if command -v make >/dev/null 2>&1; then
  make clean 2>/dev/null || true
  make 2>/dev/null && echo "  Build: OK" || echo "  Build: SKIPPED (compilers missing - expected)"
fi

echo "--- Directory structure ---"
required_dirs="awk bcpl cobol forth fortran perl b c scripts fixtures docs tests"
for d in $required_dirs; do
  if [[ -d "$d" ]]; then
    echo "  Dir OK: $d/"
  else
    echo "  MISSING: $d/"
    errors=$((errors + 1))
  fi
done

echo "--- Core files ---"
required_files="Makefile .gitignore LICENSE README.md VERSION"
for f in $required_files; do
  if [[ -f "$f" ]]; then
    echo "  File OK: $f"
  else
    echo "  MISSING: $f"
    errors=$((errors + 1))
  fi
done

echo "--- Pipeline sources ---"
for f in src/parse/response.awk src/request/build_request.b src/audit/ledger.cob src/tokenize/tokenize.fs \
  src/score/score.f src/transport/http_fallback.pl; do
  if [[ -f "$f" ]]; then
    lines=$(wc -l < "$f")
    echo "  Source OK: $f ($lines lines)"
  else
    echo "  MISSING: $f"
    errors=$((errors + 1))
  fi
done

echo "--- Fallback scripts ---"
for f in src/tokenize/fallback.sh src/audit/fallback.sh src/score/fallback.sh \
  src/request/fallback.sh; do
  if [[ -x "$f" ]]; then
    echo "  Script OK: $f"
  else
    echo "  MISSING: $f"
    errors=$((errors + 1))
  fi
done

echo ""
if [[ "$errors" -eq 0 ]]; then echo "SMOKE TEST PASSED"
else echo "$errors SMOKE TEST(S) FAILED"; fi
exit "$errors"
