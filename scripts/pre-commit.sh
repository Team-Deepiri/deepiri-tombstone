#!/usr/bin/env bash
# Pre-commit hook: run validation before each commit
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "==> pre-commit: validating fixtures"
bash scripts/validate_fixtures.sh

echo "==> pre-commit: checking shell syntax"
bash -n scripts/*.sh

echo "==> pre-commit: checking perl syntax"
perl -c src/transport/http_fallback.pl 2>/dev/null

echo "==> pre-commit: OK"
