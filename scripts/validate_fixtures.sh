#!/usr/bin/env bash
set -euo pipefail
file="${1:-fixtures/eval_prompts.txt}"
errors=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  if [[ ! "$line" == *"|"* && ! "$line" =~ [^[:space:]] ]]; then
    echo "bad line: $line"
    errors=$((errors + 1))
  fi
done < "$file"
exit "$errors"
