#!/usr/bin/env bash
set -euo pipefail
# Synthetic dataset generator fallback - rule-based only
SEED_FILE="${1:-}"
COUNT="${2:-5}"

if [[ -z "$SEED_FILE" || ! -f "$SEED_FILE" ]]; then
  echo "Usage: synth <seed-file> [variants-per-seed]" >&2
  exit 1
fi

echo "# Synthetic dataset (fallback)"
echo "# Source: $SEED_FILE"
echo ""

while IFS='|' read -r prompt keyword; do
  [[ -z "$prompt" || "$prompt" == \#* ]] && continue
  echo "$prompt|$keyword"
  echo "What is $prompt?|$keyword"
  echo "Tell me about: $prompt|$keyword"
  echo "Explain $prompt in detail|$keyword"
  echo "I need information about $prompt|$keyword"
  echo "Question: $prompt|$keyword"
done < "$SEED_FILE"
