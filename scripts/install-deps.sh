#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor"
RED=; GREEN=; RESET=;
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; RESET='\033[0m'
fi

info()  { echo -e "${GREEN}==>${RESET} $*"; }
err()   { echo -e "${RED}ERROR:${RESET} $*" >&2; }
have()  { command -v "$1" >/dev/null 2>&1; }

cleanup() { rm -f /tmp/blang_*.deb /tmp/bcpl_*.tar.gz 2>/dev/null || true; }
trap cleanup EXIT

info "deepiri-tombstone dependency installer"
info "root: $ROOT"

# ---- system packages ----
if have apt-get; then
  info "installing system packages"
  sudo apt-get update -qq
  sudo apt-get install -y -qq curl jq gcc gforth gnucobol gfortran python3 make ar xz-utils 2>&1 | tail -5
fi

# ---- ollama ----
if ! have ollama; then
  info "installing ollama"
  curl -fsSL https://ollama.com/install.sh | sh
else
  info "ollama already installed"
fi

# ---- blang (vendored) ----
mkdir -p "$VENDOR"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)   DEB_ARCH=amd64 ;;
  aarch64)  DEB_ARCH=arm64 ;;
  riscv64)  DEB_ARCH=riscv64 ;;
  *) err "unsupported arch: $ARCH"; exit 1 ;;
esac

if [[ ! -x "$VENDOR/blang" ]]; then
  TMPDEB="/tmp/blang_0.1-1_${DEB_ARCH}.deb"
  BURL="https://github.com/sergev/blang/releases/download/v0.1/blang_0.1-1_${DEB_ARCH}.deb"
  info "downloading blang ($DEB_ARCH)"
  curl -fsSL -o "$TMPDEB" "$BURL"
  TMPDIR=$(mktemp -d)
  dpkg-deb -x "$TMPDEB" "$TMPDIR"
  cp "$TMPDIR/usr/bin/blang" "$VENDOR/blang"
  cp "$TMPDIR/usr/lib/libb.a" "$VENDOR/libb.a"
  chmod +x "$VENDOR/blang"
  rm -rf "$TMPDIR"
  info "blang vendored to $VENDOR/blang"
else
  info "blang already vendored"
fi

# ---- BCPL ----
if ! have cintsys && ! have bcpl; then
  info "installing BCPL (cintsys)"
  TMPTAR="/tmp/bcpl_build.tgz"
  curl -fsSL "https://www.cl.cam.ac.uk/~mr10/bcpl4.tgz" -o "$TMPTAR" 2>/dev/null && {
    TMPDIR=$(mktemp -d)
    tar xzf "$TMPTAR" -C "$TMPDIR"
    (cd "$TMPDIR/bcpl4" && make -j4 2>/dev/null && sudo make install 2>/dev/null) || \
      info "BCPL source build skipped (not critical, fallback available)"
    rm -rf "$TMPDIR"
  } || info "BCPL download unavailable (fallback works)"
else
  info "BCPL already installed"
fi

# ---- version summary ----
info "versions"
for tool in "$VENDOR/blang" ollama gforth cobc gfortran gcc awk perl; do
  if have "$tool"; then
    echo "  $tool: $($tool --version 2>/dev/null | head -1)"
  elif have "${tool##*/}"; then
    echo "  ${tool##*/}: $(${tool##*/} --version 2>/dev/null | head -1)"
  else
    echo "  ${tool##*/}: NOT FOUND"
  fi
done

have cobc      || err "gnucobol not found — audit fallback used"
have gforth    || err "gforth not found — tokenize fallback used"
have gfortran  || err "gfortran not found — score fallback used"
[[ -x "$VENDOR/blang" ]] || err "blang not vendored — B orchestrator won't build"
info "done"
