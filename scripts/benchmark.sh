#!/usr/bin/env bash
# Benchmark the pipeline with a known model and measure throughput
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODEL="${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
ITERATIONS="${1:-5}"
FIXTURE="${2:-fixtures/eval_prompts.txt}"

if ! command -v ollama >/dev/null 2>&1; then
  echo "ERROR: ollama required for benchmarking"
  exit 1
fi

echo "=== deepiri-tombstone benchmark ==="
echo "Model:       $MODEL"
echo "Iterations:  $ITERATIONS"
echo "Fixture:     $FIXTURE"
echo ""

# Measure tokenizer
echo "--- Tokenizer ---"
total_time=0
for i in $(seq 1 "$ITERATIONS"); do
  start=$EPOCHREALTIME
  echo "hello world benchmark test $i" | bash scripts/tokenize_fallback.sh > /dev/null
  end=$EPOCHREALTIME
  elapsed=$(echo "$end - $start" | bc 2>/dev/null || echo 0.001)
  total_time=$(echo "$total_time + $elapsed" | bc 2>/dev/null || echo 0)
done
echo "  Avg tokenize time: $(echo "scale=4; $total_time / $ITERATIONS" | bc 2>/dev/null || echo 0)s"

# Measure build_request
echo "--- Request builder ---"
total_time=0
for i in $(seq 1 "$ITERATIONS"); do
  start=$EPOCHREALTIME
  bash scripts/build_request_fallback.sh "$MODEL" "benchmark prompt $i" > /dev/null
  end=$EPOCHREALTIME
  elapsed=$(echo "$end - $start" | bc 2>/dev/null || echo 0.001)
  total_time=$(echo "$total_time + $elapsed" | bc 2>/dev/null || echo 0)
done
echo "  Avg build_request time: $(echo "scale=4; $total_time / $ITERATIONS" | bc 2>/dev/null || echo 0)s"

# Measure AWK parser
echo "--- AWK parser ---"
total_time=0
for i in $(seq 1 "$ITERATIONS"); do
  start=$EPOCHREALTIME
  echo '{"response":"benchmark response '"$i"'","done":true}' | awk -f awk/parse_response.awk > /dev/null
  end=$EPOCHREALTIME
  elapsed=$(echo "$end - $start" | bc 2>/dev/null || echo 0.001)
  total_time=$(echo "$total_time + $elapsed" | bc 2>/dev/null || echo 0)
done
echo "  Avg parse time: $(echo "scale=4; $total_time / $ITERATIONS" | bc 2>/dev/null || echo 0)s"

# Clean up
rm -f reports/stats.dat reports/summary.txt

echo ""
echo "Benchmark complete"
