#!/usr/bin/env bash
# Fallback when gnucobol is not installed
set -euo pipefail
IFS='|' read -r runid model prompt response latency status || exit 1
mkdir -p reports

MODE="${DEEPIRI_TOMBSTONE_OUTPUT:-text}"
if [[ "$MODE" == "json" ]]; then
  printf '{"run_id":"%s","model":"%s","prompt":"%s","response":"%s","latency_ms":%s,"status":"%s"}\n' \
    "$runid" "$model" "$prompt" "$response" "$latency" "$status" >> reports/audit.ledger
else
  printf 'RUN-ID     %-20s MODEL      %-40s PROMPT     %-200s RESPONSE   %-500s LATENCY-MS %08s STATUS     %-4s\n' \
    "$runid" "$model" "$prompt" "$response" "$latency" "$status" >> reports/audit.ledger
fi
echo "AUDIT OK"
