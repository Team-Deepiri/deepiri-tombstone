#!/usr/bin/env bash
# Export eval results to multiple formats
# Usage: scripts/export.sh [ledger] [json|csv|jsonl|ndjson|pretty]
set -euo pipefail

LEDGER="${1:-reports/audit.ledger}"
FORMAT="${2:-json}"

if [[ ! -f "$LEDGER" ]]; then
  echo '{"error":"ledger not found"}'
  exit 1
fi

export_json() {
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
}

export_jsonl() {
  while IFS='|' read -r runid model prompt response latency status; do
    [[ -z "$runid" || "$runid" =~ ^[[:space:]]*# ]] && continue
    printf '{"run_id":"%s","model":"%s","prompt":"%s","response":"%s","latency_ms":%s,"status":"%s"}\n' \
      "$runid" "$model" "$prompt" "$response" "$latency" "$status"
  done < "$LEDGER"
}

export_pretty() {
  while IFS='|' read -r runid model prompt response latency status; do
    [[ -z "$runid" || "$runid" =~ ^[[:space:]]*# ]] && continue
    echo "=== Run $runid ==="
    echo "Model:    $model"
    echo "Prompt:   $prompt"
    echo "Response: $response"
    echo "Latency:  ${latency}ms"
    echo "Status:   $status"
    echo ""
  done < "$LEDGER"
}

export_csv() {
  echo "run_id,model,prompt,response,latency_ms,status"
  while IFS='|' read -r runid model prompt response latency status; do
    [[ -z "$runid" || "$runid" =~ ^[[:space:]]*# ]] && continue
    # Escape CSV fields
    echo "\"$runid\",\"$model\",\"$prompt\",\"$response\",$latency,\"$status\""
  done < "$LEDGER"
}

case "$FORMAT" in
  json) export_json ;;
  jsonl|ndjson) export_jsonl ;;
  csv) export_csv ;;
  pretty|text) export_pretty ;;
  *)
    echo "Usage: $0 [ledger] [json|csv|jsonl|ndjson|pretty]" >&2
    exit 1
    ;;
esac
