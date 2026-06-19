#!/usr/bin/env bash
# JSON output mode for tokenizer
set -euo pipefail
read -r line || exit 0
words=$(echo "$line" | awk '{print NF}')
budget=1
[[ "$words" -le 512 ]] || budget=0

MODE="${DEEPIRI_TOMBSTONE_OUTPUT:-text}"
if [[ "$MODE" == "json" ]]; then
  printf '{"words":%d,"budget_ok":%d,"budget_limit":512}\n' "$words" "$budget"
else
  echo "WORDS $words  BUDGET_OK $budget"
fi
