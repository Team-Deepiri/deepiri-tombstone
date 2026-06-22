#!/usr/bin/env bash
# Enhanced fallback scorer — rich metrics, categories, trending
# Usage: score <latency_ms> <response_file> [category]
set -euo pipefail

latency="${1:-}"
response_file="${2:-}"
category="${3:-general}"

if [[ -z "$latency" ]]; then
  echo "ERROR: usage: score <latency_ms> <response_file> [category]" >&2
  exit 1
fi

response_len=0
pass=0
if [[ -f "$response_file" ]]; then
  line=$(head -1 "$response_file")
  response_len=${#line}
  [[ "$response_len" -gt 0 ]] && pass=1
else
  echo "WARNING: response file not found: $response_file" >&2
fi

mkdir -p reports
timestamp=$(date '+%Y%m%d')
echo "$latency $response_len $pass $timestamp $category" >> reports/stats.dat
echo "SCORE latency=$latency length=$response_len pass=$pass cat=$category"

# Running rich stats
mean_lat=0; mean_len=0; pass_rate=0; n=0
min_lat=999999; max_lat=0; min_len=999999; max_len=0
declare -a lats lens passes
declare -A cat_pass cat_total

if [[ -f reports/stats.dat ]]; then
  while read -r l len p ts cat; do
    n=$((n + 1))
    lats+=("$l"); lens+=("$len"); passes+=("$p")
    mean_lat=$((mean_lat + l))
    mean_len=$((mean_len + len))
    pass_rate=$((pass_rate + p))
    [[ "$l" -lt "$min_lat" ]] && min_lat=$l
    [[ "$l" -gt "$max_lat" ]] && max_lat=$l
    [[ "$len" -lt "$min_len" ]] && min_len=$len
    [[ "$len" -gt "$max_len" ]] && max_len=$len
    c="${cat:-general}"
    cat_total["$c"]=$(( ${cat_total["$c"]:-0} + 1 ))
    [[ "$p" -eq 1 ]] && cat_pass["$c"]=$(( ${cat_pass["$c"]:-0} + 1 ))
  done < reports/stats.dat

  if [[ "$n" -gt 0 ]]; then
    mean_lat=$((mean_lat / n))
    mean_len=$((mean_len / n))
    pass_rate=$(echo "scale=2; 100.0 * $pass_rate / $n" | bc 2>/dev/null ||
      awk "BEGIN { printf \"%.2f\", 100.0 * $pass_rate / $n }" 2>/dev/null ||
      echo "$(( (pass_rate * 100) / n )).00")

    # Sort for percentiles
    sorted_lats=($(printf '%s\n' "${lats[@]}" | sort -n))
    sorted_lens=($(printf '%s\n' "${lens[@]}" | sort -n))

    p50_idx=$((n * 50 / 100)); [[ "$p50_idx" -ge "$n" ]] && p50_idx=$((n - 1))
    p95_idx=$((n * 95 / 100)); [[ "$p95_idx" -ge "$n" ]] && p95_idx=$((n - 1))
    p99_idx=$((n * 99 / 100)); [[ "$p99_idx" -ge "$n" ]] && p99_idx=$((n - 1))
    med_idx=$((n / 2))

    p50_lat="${sorted_lats[$p50_idx]:-0}"
    p95_lat="${sorted_lats[$p95_idx]:-0}"
    p99_lat="${sorted_lats[$p99_idx]:-0}"
    median_len="${sorted_lens[$med_idx]:-0}"

    quality=$(echo "scale=2; $pass_rate * 0.7 + (($mean_len > 50 ? 100 : $mean_len * 2)) * 0.3" | bc 2>/dev/null || echo "$pass_rate")
  fi
fi

cat > reports/summary.txt <<EOF
RUNS $n
MEAN_LATENCY_MS $mean_lat
P50_LATENCY_MS ${p50_lat:-0}
P95_LATENCY_MS ${p95_lat:-0}
P99_LATENCY_MS ${p99_lat:-0}
MIN_LATENCY_MS $min_lat
MAX_LATENCY_MS $max_lat
MEAN_LENGTH $mean_len
MEDIAN_LENGTH ${median_len:-0}
MIN_LENGTH $min_len
MAX_LENGTH $max_len
PASS_RATE_PCT ${pass_rate:-0}
QUALITY_SCORE ${quality:-0}
EOF

{
  echo "CATEGORY PASS_RATE_PCT TOTAL"
  for cat_name in "${!cat_total[@]}"; do
    if [[ -n "$cat_name" ]]; then
      total="${cat_total[$cat_name]}"
      passed="${cat_pass[$cat_name]:-0}"
      rate=$(echo "scale=2; 100.0 * $passed / $total" | bc 2>/dev/null || echo "0")
      echo "$cat_name $rate $total"
    fi
  done
} > reports/category_stats.txt

echo "$timestamp $mean_lat ${pass_rate:-0} $mean_len ${quality:-0}" >> reports/trend.dat
