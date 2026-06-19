#!/usr/bin/env bash
set -euo pipefail

echo "==> deepiri-tombstone dependency installer"

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y curl jq clang gforth gnucobol gfortran python3 make ar
fi

if ! command -v blang >/dev/null 2>&1; then
  echo "==> installing blang"
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) DEB_ARCH=amd64 ;;
    aarch64) DEB_ARCH=arm64 ;;
    riscv64) DEB_ARCH=riscv64 ;;
    *) echo "unsupported arch: $ARCH"; exit 1 ;;
  esac
  TMPDEB="/tmp/blang_0.1-1_${DEB_ARCH}.deb"
  curl -fsSL -o "$TMPDEB" \
    "https://github.com/sergev/blang/releases/download/v0.1/blang_0.1-1_${DEB_ARCH}.deb"
  sudo dpkg -i "$TMPDEB" || sudo apt-get install -f -y
fi

if ! command -v ollama >/dev/null 2>&1; then
  echo "==> installing ollama"
  curl -fsSL https://ollama.com/install.sh | sh
fi

if ! command -v gforth >/dev/null 2>&1; then
  echo "gforth missing after apt install"
  exit 1
fi

if ! command -v cobc >/dev/null 2>&1; then
  echo "gnucobol (cobc) missing after apt install"
  exit 1
fi

echo "==> versions"
blang --version 2>/dev/null || true
ollama --version 2>/dev/null || true
gforth --version 2>/dev/null | head -1 || true
cobc --version 2>/dev/null | head -1 || true
gfortran --version 2>/dev/null | head -1 || true
echo "done"
