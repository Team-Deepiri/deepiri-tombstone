#!/usr/bin/env bash
# Export eval results to JSON
set -euo pipefail

LEDGER="${1:-reports/audit.ledger}"
FORMAT="${2:-json}"

if [[ ! -f "$LEDGER" ]]; then
  echo '{"error":"ledger not found"}'
  exit 1
fi

case "$FORMAT" in
  json)
    echo '['
    first=1
    while IFS='|' read -r runid model prompt response latency status; do
      [[ -z "$runid" || "$runid" =~ ^[[:space:]]*# ]] && continue
      [[ "$first" -eq 0 ]] && echo ","
      first=0
      printf '  {"run_id":"%s","model":"%s","prompt":"%s","response":"%s","latency_ms":%s,"status":"%s"}' \
        "$runid" "$model" "$prompt" "$response" "$latency" "$status"
    done < "$LEDGER"
    echo ""
    echo ']'
    ;;
  csv)
    echo "run_id,model,prompt,response,latency_ms,status"
    while IFS='|' read -r runid model prompt response latency status; do
      [[ -z "$runid" || "$runid" =~ ^[[:space:]]*# ]] && continue
      echo "$runid,$model,$prompt,$response,$latency,$status"
    done < "$LEDGER"
    ;;
  *)
    echo "Usage: $0 [ledger] [json|csv]"
    exit 1
    ;;
esac
