#!/usr/bin/env bash
# Pre-push hook: run tests before pushing
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "==> pre-push: running tests"
bash scripts/verify_all.sh || {
  echo "ERROR: tests failed, push aborted"
  exit 1
}
echo "==> pre-push: OK"
