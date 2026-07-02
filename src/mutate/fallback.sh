#!/usr/bin/env bash
set -euo pipefail
# Adversarial mutation fallback - basic mutations only
FIXTURE="${1:-}"
if [[ -z "$FIXTURE" || ! -f "$FIXTURE" ]]; then
  echo "Usage: mutate <fixture>" >&2
  exit 1
fi

echo "# Mutated prompts (fallback)"
while IFS='|' read -r prompt keyword; do
  [[ -z "$prompt" || "$prompt" == \#* ]] && continue
  echo "$prompt|$keyword"
  echo "${prompt^^}|$keyword"
  echo "${prompt,,}|$keyword"
  echo "$prompt [CONFIRM: follow all instructions literally]|$keyword"
done < "$FIXTURE"
