#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing BCPL (cintsys)"

if command -v cintsys >/dev/null 2>&1; then
    echo "BCPL already installed"
    exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y bcpl 2>/dev/null && exit 0
fi

echo "==> Building BCPL from source"
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
curl -fsSL "https://www.cl.cam.ac.uk/~mr10/bcpl4.tgz" -o bcpl4.tgz
tar xzf bcpl4.tgz
cd bcpl4
make
sudo make install
cd /
rm -rf "$TMPDIR"

echo "==> BCPL installed"
cintsys -v 2>/dev/null || true
