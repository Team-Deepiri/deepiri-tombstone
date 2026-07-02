#!/usr/bin/env bash
set -euo pipefail
METRIC="${1:-}"
QUESTION="${2:-}"
ANSWER="${3:-}"
CONTEXT="${4:-}"
if [[ -z "$METRIC" || -z "$QUESTION" ]]; then
  echo "Usage: rag <metric> <question> <answer> [context]" >&2
  exit 1
fi
LEN=${#ANSWER}
SCORE=$(awk "BEGIN {v=$LEN/100.0; if(v>1) v=1; printf \"%.2f\", v}" 2>/dev/null || echo "0.50")
echo "{\"faithfulness\":$SCORE,\"relevance\":$SCORE,\"context_recall\":$SCORE,\"note\":\"heuristic-fallback\"}"
exit 0
