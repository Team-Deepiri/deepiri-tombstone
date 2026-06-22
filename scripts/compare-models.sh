#!/usr/bin/env bash
# Compare multiple models on the same fixture
# Usage: scripts/compare-models.sh <fixture> <model1> <model2> [model3...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FIXTURE="${1:-fixtures/eval_prompts.txt}"
shift 2>/dev/null || true

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <fixture> <model1> <model2> [model3...]" >&2
  echo ""
  echo "Compare multiple models on the same eval fixture."
  echo "Models are looked up via DEEPIRI_TOMBSTONE_HOST Ollama instance."
  echo ""
  echo "Example:"
  echo "  $0 fixtures/eval_prompts.txt llama3.2 llama3.1 mistral"
  exit 1
fi

echo "=== deepiri-tombstone multi-model comparison ==="
echo "Fixture: $FIXTURE"
echo "Models:  $*"
echo ""

RESULTS_DIR="reports/comparisons/$(date '+%Y%m%d_%H%M%S')"
mkdir -p "$RESULTS_DIR"

SUMMARY_FILE="$RESULTS_DIR/comparison_summary.txt"
MD_FILE="$RESULTS_DIR/comparison_report.md"

# Check fixture exists
if [[ ! -f "$FIXTURE" ]]; then
  echo "ERROR: fixture not found: $FIXTURE" >&2
  exit 1
fi

echo "# Model Comparison Report" > "$MD_FILE"
echo "" >> "$MD_FILE"
echo "**Date:** $(date)" >> "$MD_FILE"
echo "**Fixture:** $FIXTURE" >> "$MD_FILE"
echo "**Models:** $*" >> "$MD_FILE"
echo "" >> "$MD_FILE"
echo "## Summary" >> "$MD_FILE"
echo "" >> "$MD_FILE"
echo "| Model | Prompt Count | Pass Count | Pass Rate | Mean Latency | Mean Length | Quality Score |" >> "$MD_FILE"
echo "|-------|-------------|-----------|-----------|-------------|------------|--------------|" >> "$MD_FILE"

declare -A model_passes model_total model_lat model_len

for model in "$@"; do
  echo "--- Evaluating: $model ---"
  MODEL_DIR="$RESULTS_DIR/$model"
  mkdir -p "$MODEL_DIR"
  
  export DEEPIRI_TOMBSTONE_MODEL="$model"
  
  passes=0
  total=0
  lat_sum=0
  len_sum=0
  model_report="$MODEL_DIR/results.txt"
  
  > "$model_report"
  
  while IFS='|' read -r prompt keyword; do
    [[ -z "$prompt" || "$prompt" =~ ^[[:space:]]*# ]] && continue
    total=$((total + 1))
    
    echo -n "  [$total] $prompt ... "
    
    TIMESTAMP=$(date +%s%N)
    RAW=$(timeout 120 curl -sf "http://${DEEPIRI_TOMBSTONE_HOST:-127.0.0.1:11434}/api/generate" \
      -d "$(python3 -c "import json; print(json.dumps({'model':'$model','prompt':'''$prompt''','stream':False}))" 2>/dev/null)" 2>/dev/null || echo '{"response":"(fail)"}')
    LATENCY=$(( ($(date +%s%N) - TIMESTAMP) / 1000000 ))
    
    RESPONSE=$(echo "$RAW" | awk -f src/parse/response.awk 2>/dev/null || echo "(parse error)")
    
    if grep -qi "${keyword:-}" <<< "$RESPONSE" 2>/dev/null; then
      echo "PASS" >> "$model_report"
      passes=$((passes + 1))
      echo "PASS"
    else
      echo "FAIL" >> "$model_report"
      echo "FAIL"
    fi
    
    lat_sum=$((lat_sum + LATENCY))
    len_sum=$((len_sum + ${#RESPONSE}))
    
    # Don't hit Ollama too hard
    sleep 0.5
  done < "$FIXTURE"
  
  pass_rate=$(echo "scale=1; 100.0 * $passes / $total" | bc 2>/dev/null || echo "0")
  mean_lat=$((total > 0 ? lat_sum / total : 0))
  mean_len=$((total > 0 ? len_sum / total : 0))
  quality=$(echo "scale=1; $pass_rate * 0.7 + ($mean_len > 50 ? 100 : $mean_len * 2) * 0.3" | bc 2>/dev/null || echo "$pass_rate")
  
  model_passes["$model"]=$passes
  model_total["$model"]=$total
  model_lat["$model"]=$mean_lat
  model_len["$model"]=$mean_len
  
  echo "| $model | $total | $passes | ${pass_rate}% | ${mean_lat}ms | $mean_len | ${quality} |" >> "$MD_FILE"
  echo ""
  echo "  Result: $passes/$total pass (${pass_rate}%), avg ${mean_lat}ms"
  echo ""
done

echo "" >> "$MD_FILE"
echo "## Details" >> "$MD_FILE"
echo "" >> "$MD_FILE"

# Per-prompt comparison table
echo "| # | Prompt | $(echo "$*" | tr ' ' '|') |" >> "$MD_FILE"
SEP="|---|-------"
for _ in "$@"; do SEP="$SEP|---"; done
echo "$SEP |" >> "$MD_FILE"

line_num=0
while IFS='|' read -r prompt keyword; do
  [[ -z "$prompt" || "$prompt" =~ ^[[:space:]]*# ]] && continue
  line_num=$((line_num + 1))
  
  row="| $line_num | ${prompt:0:60}..."
  for model in "$@"; do
    result_file="$RESULTS_DIR/$model/results.txt"
    result=$(sed -n "${line_num}p" "$result_file" 2>/dev/null || echo "N/A")
    row="$row | $result"
  done
  echo "$row |" >> "$MD_FILE"
done < "$FIXTURE"

# Find winner
best_model=""
best_rate=0
for model in "$@"; do
  rate=$(echo "scale=5; ${model_passes[$model]} / ${model_total[$model]}" | bc 2>/dev/null || echo "0")
  if (( $(echo "$rate > $best_rate" | bc -l 2>/dev/null || echo "0") )); then
    best_rate=$rate
    best_model=$model
  fi
done

echo "" >> "$MD_FILE"
echo "## Winner" >> "$MD_FILE"
echo "" >> "$MD_FILE"
echo "**$best_model** achieved the highest pass rate on this fixture." >> "$MD_FILE"

cp "$MD_FILE" reports/comparison_latest.md
echo "=== Comparison report written to $MD_FILE ==="
echo "Summary:"
{
  echo "Model comparison ($FIXTURE):"
  for model in "$@"; do
    echo "  $model: ${model_passes[$model]}/${model_total[$model]} pass, ${model_lat[$model]}ms avg latency"
  done
  echo "Winner: $best_model"
} | tee "$SUMMARY_FILE"
