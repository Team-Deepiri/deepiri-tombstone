#!/usr/bin/env bash
# Show a summary of the project
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "╔══════════════════════════════════════╗"
echo "║  deepiri-tombstone                   ║"
echo "║  Post-training eval for Ollama       ║"
echo "╚══════════════════════════════════════╝"
echo ""

echo "Version:  $(cat VERSION 2>/dev/null || echo 'unknown')"
echo "Commits:  $(git rev-list --count HEAD 2>/dev/null || echo 0)"
echo "Branch:   $(git branch --show-current 2>/dev/null || echo 'unknown')"
echo ""

echo "Pipeline:"
echo "  Tokenize  → Forth        (forth/tokenize.fs)"
echo "  Generate  → C bridge     (c/ollama_bridge.c)"
echo "  Parse     → AWK          (awk/parse_response.awk)"
echo "  Score     → Fortran      (fortran/score.f)"
echo "  Audit     → COBOL        (cobol/audit.cob)"
echo "  Fallback  → Perl         (perl/http_fallback.pl)"
echo "  Request   → BCPL         (bcpl/build_request.b)"
echo "  Orches.   → B            (b/main.b)"
echo ""

echo "Status:"
for f in bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback bin/deepiri-tombstone-core; do
  if [[ -f "$f" ]]; then
    echo "  ✓ $f"
  fi
done

echo ""
echo "Reports:"
for f in reports/audit.ledger reports/stats.dat reports/summary.txt; do
  if [[ -f "$f" ]]; then
    echo "  $f ($(wc -l < "$f") lines)"
  fi
done
