#!/usr/bin/env bash
# Fallback when gfortran is not installed
set -euo pipefail
latency="${1:-0}"
response_file="${2:-}"
response_len=0
pass=0
if [[ -f "$response_file" ]]; then
  line=$(head -1 "$response_file")
  response_len=${#line}
  [[ "$response_len" -gt 0 ]] && pass=1
fi
mkdir -p reports
echo "$latency $response_len $pass" >> reports/stats.dat
echo "SCORE latency=$latency length=$response_len pass=$pass"
mean_lat=0; mean_len=0; pass_rate=0; n=0
if [[ -f reports/stats.dat ]]; then
  while read -r l len p; do
    n=$((n + 1))
    mean_lat=$((mean_lat + l))
    mean_len=$((mean_len + len))
    pass_rate=$((pass_rate + p))
  done < reports/stats.dat
  if [[ "$n" -gt 0 ]]; then
    mean_lat=$((mean_lat / n))
    mean_len=$((mean_len / n))
    pass_rate=$(echo "scale=2; 100.0 * $pass_rate / $n" | bc 2>/dev/null || echo "N/A")
  fi
fi
cat > reports/summary.txt <<EOF
RUNS $n
MEAN_LATENCY_MS $mean_lat
MEAN_LENGTH $mean_len
PASS_RATE_PCT $pass_rate
EOF
