#!/usr/bin/env bash
# Print the current pipeline configuration
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Configuration ==="
echo "DEEPIRI_TOMBSTONE_HOST=${DEEPIRI_TOMBSTONE_HOST:-127.0.0.1:11434}"
echo "DEEPIRI_TOMBSTONE_MODEL=${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
echo "DEEPIRI_TOMBSTONE_OUTPUT=${DEEPIRI_TOMBSTONE_OUTPUT:-text}"

echo ""
echo "=== Compilers ==="
for prog in gforth cobc gfortran gcc perl awk cintsys; do
  if command -v "$prog" >/dev/null 2>&1; then
    echo "  $prog: $($prog --version 2>/dev/null | head -1)"
  else
    echo "  $prog: NOT INSTALLED"
  fi
done

echo ""
echo "=== Vendored ==="
echo "  vendor/blang: $([[ -x vendor/blang ]] && echo OK || echo MISSING)"
echo "  vendor/libb.a: $([[ -f vendor/libb.a ]] && echo OK || echo MISSING)"

echo ""
echo "=== Reports ==="
for f in reports/audit.ledger reports/stats.dat reports/summary.txt; do
  if [[ -f "$f" ]]; then
    echo "  $f: $(wc -l < "$f") lines"
  fi
done

echo ""
echo "=== Binaries ==="
for f in bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback bin/deepiri-tombstone-core; do
  if [[ -f "$f" ]]; then
    echo "  $f: $(file "$f" | cut -d: -f2)"
  else
    echo "  $f: NOT BUILT"
  fi
done
