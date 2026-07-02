#!/usr/bin/env bash
set -euo pipefail
CHECK="${1:-}"
TEXT="${2:-}"
if [[ -z "$CHECK" || -z "$TEXT" ]]; then
  echo "Usage: guard <jailbreak|safety|leakage|all> <text> [-r response]" >&2
  exit 1
fi
LEN=${#TEXT}
# Heuristic: long prompts with special chars might be jailbreaks
if echo "$TEXT" | grep -qiE "(ignore|forget|override|DAN|jailbreak|system prompt|you are now)"; then
  JB=0.8
else
  JB=0.1
fi
echo "{\"$CHECK\":{\"score\":$JB,\"note\":\"heuristic-fallback\"}}"
exit 0
