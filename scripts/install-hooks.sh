#!/usr/bin/env bash
# Run this once: bash scripts/install-hooks.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ln -sf ../../scripts/pre-commit.sh "$ROOT/.git/hooks/pre-commit"
chmod +x "$ROOT/.git/hooks/pre-commit"
echo "pre-commit hook installed"
