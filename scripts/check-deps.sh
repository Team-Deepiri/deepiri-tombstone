#!/usr/bin/env bash
# Check that all required tools are available
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

eval "$(bash scripts/os-detect.sh)"

missing=0
check() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1 (NOT FOUND)"
    missing=$((missing + 1))
  fi
}

echo "=== Platform: $OS/$DISTRO ($ARCH) ==="
echo ""

echo "=== Required ==="
check gcc
check make
check git
if [[ "$OS" != "macos" ]]; then
  check ar
fi

echo "=== Pipeline compilers (optional — fallbacks exist) ==="
check gforth
check cobc
check gfortran
check perl
check awk

echo "=== Runtime ==="
check curl
check ollama

echo "=== Vendored ==="
if [[ -x vendor/blang ]]; then
  echo "  ✓ vendor/blang"
else
  echo "  ✗ vendor/blang (run scripts/install-deps.sh)"
  missing=$((missing + 1))
fi
if [[ -f vendor/libb.a ]]; then
  echo "  ✓ vendor/libb.a"
else
  echo "  ✗ vendor/libb.a (run scripts/install-deps.sh)"
  missing=$((missing + 1))
fi

echo ""
if [[ "$missing" -eq 0 ]]; then
  echo "All dependencies satisfied"
else
  echo "$missing dependency(ies) missing"
fi
exit "$missing"
