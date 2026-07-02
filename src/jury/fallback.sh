#!/usr/bin/env bash
set -euo pipefail
PROMPT="${1:-}"
RESPONSE="${2:-}"
shift 2 2>/dev/null || true
JURORS=("$@")
if [[ -z "$PROMPT" || -z "$RESPONSE" ]]; then
  echo "Usage: jury <prompt> <response> [juror1 juror2 ...]" >&2
  exit 1
fi
LEN=${#RESPONSE}
SCORE=1
[[ $LEN -gt 20 ]] && SCORE=2
[[ $LEN -gt 60 ]] && SCORE=3
[[ $LEN -gt 120 ]] && SCORE=4
[[ $LEN -gt 200 ]] && SCORE=5
echo "{\"relevance\":$SCORE,\"coherence\":$SCORE,\"accuracy\":$SCORE,\"completeness\":$SCORE,\"overall\":$SCORE,\"jurors\":${#JURORS[@]},\"consensus\":\"heuristic\",\"note\":\"fallback\"}"
exit 0
