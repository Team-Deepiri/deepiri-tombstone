#!/usr/bin/env bash
# Search prompts in a fixture file by keyword
set -euo pipefail

FIXTURE="${1:-fixtures/eval_prompts.txt}"
SEARCH="${2:-}"

if [[ -z "$SEARCH" ]]; then
  echo "Usage: $0 <fixture> <search-term>"
  exit 1
fi

if [[ ! -f "$FIXTURE" ]]; then
  echo "Fixture not found: $FIXTURE"
  exit 1
fi

matched=0
while IFS='|' read -r prompt keyword; do
  if echo "$prompt" | grep -qi "$SEARCH" || echo "$keyword" | grep -qi "$SEARCH"; then
    echo "$prompt|$keyword"
    matched=$((matched + 1))
  fi
done < "$FIXTURE"

if [[ "$matched" -eq 0 ]]; then
  echo "No matches for '$SEARCH' in $FIXTURE"
  exit 1
fi
