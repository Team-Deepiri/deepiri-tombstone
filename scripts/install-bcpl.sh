#!/usr/bin/env bash
# Install BCPL (cintsys) compiler
set -euo pipefail

if command -v cintsys >/dev/null 2>&1; then
    echo "BCPL already installed"
    cintsys -v 2>/dev/null || true
    exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
    echo "Trying apt package..."
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -y bcpl 2>/dev/null && exit 0
fi

echo "Building BCPL from source..."
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

if curl -fsSL "https://www.cl.cam.ac.uk/~mr10/bcpl4.tgz" -o bcpl4.tgz; then
    tar xzf bcpl4.tgz
    cd bcpl4
    make -j4 2>/dev/null && sudo make install 2>/dev/null && {
        echo "BCPL installed successfully"
        cd /
        rm -rf "$TMPDIR"
        exit 0
    }
fi

echo "BCPL source build skipped (not critical — shell fallback available)"
cd /
rm -rf "$TMPDIR"
exit 0
