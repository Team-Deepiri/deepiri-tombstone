#!/usr/bin/env bash
# Trend analysis — compare current run against historical runs
# Usage: scripts/trend.sh [trend_file]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TREND_FILE="${1:-reports/trend.dat}"
SUMMARY="${2:-reports/summary.txt}"

echo "=== deepiri-tombstone trend analysis ==="
echo ""

if [[ ! -f "$TREND_FILE" ]]; then
  echo "No trend data found at $TREND_FILE"
  echo "Run some evals first: deepiri-tombstone eval"
  echo ""
  echo "Trend data is collected in reports/trend.dat each time"
  echo "the scorer runs. Each record contains:"
  echo "  timestamp mean_latency pass_rate mean_length quality_score"
  exit 0
fi

echo "Historical runs:"
echo "---------------"
printf "%-12s %12s %10s %12s %12s\n" "DATE" "LAT_MS" "PASS%" "LENGTH" "QUALITY"
echo "------------ ---------- ---------- ------------ ------------"

runs=0
while read -r ts lat pass_rate len qual; do
  [[ -z "$ts" || "$ts" == "DATE" ]] && continue
  printf "%-12s %10s %10s %10s %10s\n" "$ts" "$lat" "$pass_rate" "$len" "$qual"
  runs=$((runs + 1))
done < "$TREND_FILE"

echo ""
echo "Total runs recorded: $runs"

if [[ "$runs" -ge 2 ]]; then
  echo ""
  echo "Regression analysis (comparing last 2 runs):"
  
  last=$(tail -1 "$TREND_FILE")
  prev=$(tail -2 "$TREND_FILE" | head -1)
  
  last_ts=$(echo "$last" | awk '{print $1}')
  last_lat=$(echo "$last" | awk '{print $2}')
  last_pass=$(echo "$last" | awk '{print $3}')
  last_qual=$(echo "$last" | awk '{print $5}')
  
  prev_ts=$(echo "$prev" | awk '{print $1}')
  prev_lat=$(echo "$prev" | awk '{print $2}')
  prev_pass=$(echo "$prev" | awk '{print $3}')
  prev_qual=$(echo "$prev" | awk '{print $5}')
  
  echo "  From $prev_ts to $last_ts:"
  
  lat_diff=$(echo "$last_lat - $prev_lat" | bc 2>/dev/null || echo "0")
  pass_diff=$(echo "$last_pass - $prev_pass" | bc 2>/dev/null || echo "0")
  qual_diff=$(echo "$last_qual - $prev_qual" | bc 2>/dev/null || echo "0")
  
  echo "    Latency:   $prev_lat -> $last_lat (${lat_diff}ms)"
  echo "    Pass rate: ${prev_pass}% -> ${last_pass}% (${pass_diff}pp)"
  echo "    Quality:   ${prev_qual} -> ${last_qual} (${qual_diff})"
  
  if (( $(echo "$pass_diff > 0" | bc -l 2>/dev/null) )); then
    echo "    Status: IMPROVEMENT"
  elif (( $(echo "$pass_diff < 0" | bc -l 2>/dev/null) )); then
    echo "    Status: REGRESSION"
  else
    echo "    Status: STABLE"
  fi
fi

# Current run summary
if [[ -f "$SUMMARY" ]]; then
  echo ""
  echo "Current run summary:"
  cat "$SUMMARY"
fi
