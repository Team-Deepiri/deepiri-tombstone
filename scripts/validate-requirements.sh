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
  scripts/tokenize_fallback.sh scripts/audit_fallback.sh scripts/score_fallback.sh \
  scripts/build_request_fallback.sh scripts/run-b.sh; do
  if [[ -x "$script" ]]; then
    echo "  OK: $script"
  else
    echo "  MISSING: $script"
    errors=$((errors + 1))
  fi
done

echo "--- Language sources ---"
for src in awk/parse_response.awk bcpl/build_request.b cobol/audit.cob forth/tokenize.fs \
  fortran/score.f perl/http_fallback.pl b/main.b b/cli.b b/util.b c/ollama_bridge.c; do
  if [[ -f "$src" ]]; then
    echo "  OK: $src"
  else
    echo "  MISSING: $src"
    errors=$((errors + 1))
  fi
fi

echo "--- Documentation ---"
for doc in README.md CHANGELOG.md LICENSE docs/README.md docs/ARCHITECTURE.md \
  docs/OPENCODE.md docs/PIPELINE.md docs/TUTORIAL.md; do
  if [[ -f "$doc" ]]; then
    echo "  OK: $doc"
  else
    echo "  MISSING: $doc"
    errors=$((errors + 1))
  fi
fi

echo ""
if [[ "$errors" -eq 0 ]]; then
  echo "All requirements satisfied"
else
  echo "$errors requirement(s) missing"
fi
exit "$errors"
