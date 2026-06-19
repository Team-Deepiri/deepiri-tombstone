#!/usr/bin/env bash
# Add a prompt to a fixture file
set -euo pipefail

FIXTURE="${1:-fixtures/eval_prompts.txt}"
PROMPT="${2:-}"
KEYWORD="${3:-}"

if [[ -z "$PROMPT" ]]; then
  echo "Usage: $0 <fixture> <prompt> [keyword]"
  echo "  Add a prompt to a fixture file"
  exit 1
fi

if [[ -n "$KEYWORD" ]]; then
  echo "$PROMPT|$KEYWORD" >> "$FIXTURE"
else
  echo "$PROMPT|" >> "$FIXTURE"
fi
echo "Added to $FIXTURE: $PROMPT|$KEYWORD"
