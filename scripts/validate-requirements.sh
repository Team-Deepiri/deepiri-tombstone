#!/usr/bin/env bash
# Validate requirements for each pipeline component
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
errors=0

echo "=== Requirements validation ==="

# Check all executables exist and are executable
echo "--- Required scripts ---"
for script in scripts/install-deps.sh scripts/pull-model.sh scripts/validate_fixtures.sh \
  src/tokenize/fallback.sh src/audit/fallback.sh src/score/fallback.sh \
  src/request/fallback.sh scripts/run-b.sh; do
  if [[ -x "$script" ]]; then
    echo "  OK: $script"
  else
    echo "  MISSING: $script"
    errors=$((errors + 1))
  fi
done

echo "--- Language sources ---"
for src in src/parse/response.awk src/request/build_request.b src/audit/ledger.cob src/tokenize/tokenize.fs \
  src/score/score.f src/transport/http_fallback.pl src/orchestrator/main.b src/orchestrator/cli.b src/orchestrator/util.b src/bridge/ollama_bridge.c; do
  if [[ -f "$src" ]]; then
    echo "  OK: $src"
  else
    echo "  MISSING: $src"
    errors=$((errors + 1))
  fi
done

echo "--- Documentation ---"
for doc in README.md CHANGELOG.md LICENSE docs/README.md docs/ARCHITECTURE.md \
  docs/OPENCODE.md docs/PIPELINE.md docs/TUTORIAL.md; do
  if [[ -f "$doc" ]]; then
    echo "  OK: $doc"
  else
    echo "  MISSING: $doc"
    errors=$((errors + 1))
  fi
done

echo ""
if [[ "$errors" -eq 0 ]]; then
  echo "All requirements satisfied"
else
  echo "$errors requirement(s) missing"
fi
exit "$errors"
