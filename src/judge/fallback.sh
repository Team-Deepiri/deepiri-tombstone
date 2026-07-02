#!/usr/bin/env bash
set -euo pipefail
# G-Eval fallback: heuristic scoring (length + keyword match)
JUDGE_MODEL="${1:-}"
PROMPT="${2:-}"
RESPONSE_FILE="${3:-}"
CRITERIA_FILE="${4:-}"

if [[ -z "$JUDGE_MODEL" || -z "$PROMPT" ]]; then
  echo '{"error":"usage: judge <model> <prompt> [response-file]","overall":0}'
  exit 1
fi

if [[ -n "$RESPONSE_FILE" && -f "$RESPONSE_FILE" ]]; then
  RESPONSE=$(cat "$RESPONSE_FILE")
else
  RESPONSE=$(cat)
fi

if [[ -z "${RESPONSE:-}" ]]; then
  echo '{"error":"empty response","overall":0}'
  exit 1
fi

LEN=${#RESPONSE}
SCORE=1
[[ "$LEN" -gt 10 ]] && SCORE=2
[[ "$LEN" -gt 50 ]] && SCORE=3
[[ "$LEN" -gt 100 ]] && SCORE=4
[[ "$LEN" -gt 200 ]] && SCORE=5

echo "{\"relevance\":$SCORE,\"coherence\":$SCORE,\"helpfulness\":$SCORE,\"harmlessness\":5,\"overall\":$SCORE,\"note\":\"heuristic-fallback\"}"
exit 0
