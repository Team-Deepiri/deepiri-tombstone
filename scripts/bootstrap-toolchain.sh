#!/usr/bin/env bash
# Bootstrap vendored blang + clang without sudo
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}"

mkdir -p "$ROOT/vendor"

if [[ ! -x "$ROOT/vendor/blang" ]]; then
  curl -fsSL -o "$TMP/blang.deb" \
    https://github.com/sergev/blang/releases/download/v0.1/blang_0.1-1_amd64.deb
  dpkg-deb -x "$TMP/blang.deb" "$TMP/blang_extract"
  cp "$TMP/blang_extract/usr/bin/blang" "$ROOT/vendor/"
  cp "$TMP/blang_extract/usr/lib/libb.a" "$ROOT/vendor/"
fi

if [[ ! -x "$ROOT/vendor/llvm/usr/bin/clang-18" ]]; then
  cd "$TMP"
  apt-get download clang-18 libclang-cpp18 libllvm18 llvm-18-linker-tools libclang1-18 libclang-common-18-dev
  mkdir -p "$ROOT/vendor/llvm"
  for deb in clang-18_*.deb libclang-cpp18_*.deb libllvm18_*.deb llvm-18-linker-tools_*.deb libclang1-18_*.deb libclang-common-18-dev_*.deb; do
    dpkg-deb -x "$deb" "$ROOT/vendor/llvm"
  done
fi

echo "toolchain ready under $ROOT/vendor"
