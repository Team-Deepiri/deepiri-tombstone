#!/usr/bin/env bash
# Comprehensive throughput benchmark for all pipeline components
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODEL="${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
ITERATIONS="${1:-10}"
FIXTURE="${2:-fixtures/eval_prompts.txt}"

echo "╔══════════════════════════════════════════════╗"
echo "║     deepiri-tombstone Benchmark Suite        ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Model:       $MODEL"
echo "Iterations:  $ITERATIONS"
echo "Fixture:     $FIXTURE"
echo ""

RESULTS_FILE="reports/benchmark_results.txt"

bench_component() {
  local name="$1" cmd="$2" input="$3"
  local total_time=0 min_time=999999 max_time=0
  local times=()
  
  echo "--- $name ---"
  for i in $(seq 1 "$ITERATIONS"); do
    start=$EPOCHREALTIME 2>/dev/null || start=$(date +%s.%N)
    eval "$cmd" > /dev/null 2>&1
    end=$EPOCHREALTIME 2>/dev/null || end=$(date +%s.%N)
    elapsed=$(echo "$end - $start" | bc 2>/dev/null || echo "0.001")
    total_time=$(echo "$total_time + $elapsed" | bc 2>/dev/null || echo "0")
    
    # Convert to integer microseconds for sorting
    int_val=$(echo "$elapsed * 1000000" | bc 2>/dev/null | cut -d. -f1 || echo "1000")
    times+=("$int_val")
    
    if (( $(echo "$elapsed < $min_time" | bc -l 2>/dev/null) )); then
      min_time=$elapsed
    fi
    if (( $(echo "$elapsed > $max_time" | bc -l 2>/dev/null) )); then
      max_time=$elapsed
    fi
  done
  
  mean=$(echo "scale=6; $total_time / $ITERATIONS" | bc 2>/dev/null || echo "0")
  
  # Sort for median
  IFS=$'\n' sorted=($(sort -n <<<"${times[*]}")); unset IFS
  med_idx=$((ITERATIONS / 2))
  median_us=${sorted[$med_idx]:-0}
  median=$(echo "scale=6; $median_us / 1000000" | bc 2>/dev/null || echo "0")
  
  echo "  Mean:   ${mean}s"
  echo "  Median: ${median}s"
  echo "  Min:    ${min_time}s"
  echo "  Max:    ${max_time}s"
  echo "  Total:  ${total_time}s"
  echo ""
  
  echo "$name|$mean|$median|$min_time|$max_time|$total_time" >> "$RESULTS_FILE"
}

echo "Results will be saved to $RESULTS_FILE"
rm -f "$RESULTS_FILE"
echo "COMPONENT|MEAN|MEDIAN|MIN|MAX|TOTAL" > "$RESULTS_FILE"

# Tokenizer
bench_component "tokenize" \
  "echo 'hello world benchmark test' | bash src/tokenize/fallback.sh" \
  ""

# Request builder
bench_component "build_request" \
  "bash src/request/fallback.sh '$MODEL' 'benchmark prompt test'" \
  ""

# AWK parser
bench_component "awk_parse" \
  "echo '{\"response\":\"benchmark response test data for measuring throughput\"}' | awk -f src/parse/response.awk" \
  ""

# Scorer (fallback)
bench_component "score" \
  "bash src/score/fallback.sh 500 /dev/null <<< 'benchmark response'" \
  ""

# Auditor (fallback)
bench_component "audit" \
  "echo 'run-bench|test|prompt|response|500|PASS' | bash src/audit/fallback.sh" \
  ""

# Fixture validation
bench_component "fixture_validate" \
  "bash scripts/validate_fixtures.sh '$FIXTURE' 2>/dev/null" \
  ""

echo "=== Summary ==="
echo ""
echo "Component       Mean      Median    Min       Max"
echo "--------------- --------- --------- --------- ---------"
while IFS='|' read -r comp mean med min max total; do
  [[ "$comp" == "COMPONENT" ]] && continue
  printf "%-15s %8s %8s %8s %8s\n" "$comp" "${mean}s" "${med}s" "${min}s" "${max}s"
done < "$RESULTS_FILE"

echo ""
echo "Benchmark complete — see $RESULTS_FILE"
