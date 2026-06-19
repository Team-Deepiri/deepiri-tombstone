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

# ---- OS detection ----
eval "$(bash "$ROOT/scripts/os-detect.sh")"
info "detected: $OS/$DISTRO ($ARCH)"

info "deepiri-tombstone dependency installer"
info "root: $ROOT"

# ---- system packages ----
case "$OS" in
  linux)
    if have apt-get; then
      info "installing system packages (apt)"
      sudo apt-get update -qq
      sudo apt-get install -y -qq curl jq gcc gforth gnucobol gfortran python3 make binutils xz-utils 2>&1 | tail -5
    elif have dnf; then
      info "installing system packages (dnf)"
      sudo dnf install -y curl jq gcc gforth gnucobol gcc-gfortran python3 make binutils xz 2>&1 | tail -5
    elif have apk; then
      info "installing system packages (apk)"
      apk add --no-cache curl jq gcc gforth gnucobol gfortran python3 make binutils xz 2>&1 | tail -5
    fi
    ;;
  macos)
    if have brew; then
      info "installing system packages (homebrew)"
      brew install curl jq gcc gforth gnucobol gfortran python3 make xz 2>&1 | tail -5
    else
      err "Homebrew not found — install from https://brew.sh"
    fi
    ;;
  windows)
    err "Windows is not directly supported. Use Docker or WSL."
    exit 1
    ;;
esac

# ---- ollama ----
if ! have ollama; then
  info "installing ollama"
  curl -fsSL https://ollama.com/install.sh | sh
else
  info "ollama already installed"
fi

# ---- blang (vendored) ----
mkdir -p "$VENDOR"

if [[ ! -x "$VENDOR/blang" ]]; then
  case "$OS" in
    linux)
      case "$ARCH" in
        x86_64)   DEB_ARCH=amd64 ;;
        aarch64)  DEB_ARCH=arm64 ;;
        riscv64)  DEB_ARCH=riscv64 ;;
        *) err "unsupported arch: $ARCH"; exit 1 ;;
      esac
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
      ;;
    macos)
      info "blang has no macOS binary release — building from source"
      TMPDIR=$(mktemp -d)
      curl -fsSL "https://github.com/sergev/blang/archive/refs/tags/v0.1.tar.gz" -o "$TMPDIR/blang.tar.gz"
      tar xzf "$TMPDIR/blang.tar.gz" -C "$TMPDIR"
      (cd "$TMPDIR/blang-0.1" && make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)" && cp blang "$VENDOR/blang" && chmod +x "$VENDOR/blang") || \
        err "blang source build failed — B orchestrator won't be available"
      rm -rf "$TMPDIR"
      ;;
  esac
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
    MAKEOPTS="-j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
    (cd "$TMPDIR/bcpl4" && make "$MAKEOPTS" 2>/dev/null && sudo make install 2>/dev/null) || \
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
