#!/usr/bin/env bash
# Set up development environment after clone
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== deepiri-tombstone dev setup ==="

if [[ -f .env ]]; then
  echo "Loading .env"
  set -a; source .env; set +a
fi

echo "Installing dependencies..."
bash scripts/install-deps.sh

echo "Installing git hooks..."
bash scripts/install-hooks.sh

echo "Building..."
make 2>/dev/null && echo "Build OK" || echo "Build skipped (some compilers may be missing)"

echo ""
echo "Setup complete. Run:"
echo "  make test  — verify everything works"
echo "  ./scripts/pull-model.sh  — pull an Ollama model"
echo "  ./deepiri-tombstone ping  — check Ollama"
