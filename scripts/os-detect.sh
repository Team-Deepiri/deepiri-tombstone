#!/usr/bin/env bash
# Detect operating system and distribution
set -euo pipefail

OS="unknown"
DISTRO="unknown"
ARCH="$(uname -m)"

case "$(uname -s)" in
  Linux)
    OS="linux"
    if [[ -f /etc/os-release ]]; then
      . /etc/os-release
      DISTRO="$ID"
    elif command -v lsb_release >/dev/null 2>&1; then
      DISTRO=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
    fi
    ;;
  Darwin)
    OS="macos"
    DISTRO="macos"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    OS="windows"
    DISTRO="windows"
    ;;
esac

echo "OS=$OS"
echo "DISTRO=$DISTRO"
echo "ARCH=$ARCH"

# Package manager
case "$DISTRO" in
  ubuntu|debian)   PKG="apt-get" ;;
  fedora|rhel|centos) PKG="dnf" ;;
  alpine)          PKG="apk" ;;
  arch)            PKG="pacman" ;;
  macos)           PKG="brew" ;;
  *)               PKG="unknown" ;;
esac
echo "PKG=$PKG"
