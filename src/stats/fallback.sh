#!/usr/bin/env bash
set -euo pipefail
FILE="${1:-reports/stats.dat}"
ACTION="${2:-summary}"
if [[ ! -f "$FILE" ]]; then
  echo "No stats file: $FILE" >&2
  exit 1
fi
total=$(wc -l < "$FILE")
lat_sum=$(awk '{s+=$1}END{print s}' "$FILE")
len_sum=$(awk '{s+=$2}END{print s}' "$FILE")
pass_sum=$(awk '{s+=$3}END{print s}' "$FILE")
mean_lat=$((lat_sum / (total > 0 ? total : 1)))
mean_len=$((len_sum / (total > 0 ? total : 1)))
pass_rate=$((pass_sum * 100 / (total > 0 ? total : 1)))
echo "{\"n\":$total,\"mean_latency_ms\":$mean_lat,\"mean_length\":$mean_len,\"pass_rate\":$pass_rate,\"passes\":$pass_sum,\"file\":\"$FILE\"}"
