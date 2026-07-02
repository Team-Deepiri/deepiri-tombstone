#!/usr/bin/env bash
set -euo pipefail
# Multi-model benchmark fallback - runs basic comparison
FIXTURE="${1:-}"
shift 2>/dev/null || true
MODELS=("$@")

if [[ -z "$FIXTURE" || ${#MODELS[@]} -eq 0 ]]; then
  echo "Usage: bench <fixture> <model1> [model2 ...]" >&2
  exit 1
fi

echo "# Benchmark results (fallback)"
echo "# Fixture: $FIXTURE"
echo "# Models: ${MODELS[*]}"
echo ""

for model in "${MODELS[@]}"; do
  passes=0
  total=0
  total_latency=0
  while IFS='|' read -r prompt keyword; do
    [[ -z "$prompt" || "$prompt" == \#* ]] && continue
    total=$((total + 1))
    start=$(date +%s%N)
    response=$(curl -sf "http://${DEEPIRI_TOMBSTONE_HOST:-127.0.0.1:11434}/api/generate" \
      -d "{\"model\":\"$model\",\"prompt\":\"$prompt\",\"stream\":false}" 2>/dev/null | \
      python3 -c "import sys,json; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo "")
    end=$(date +%s%N)
    latency=$(( (end - start) / 1000000 ))
    total_latency=$((total_latency + latency))
    if echo "$response" | grep -qi "$keyword"; then
      passes=$((passes + 1))
    fi
  done < "$FIXTURE"
  
  rate=0
  [[ $total -gt 0 ]] && rate=$((passes * 100 / total))
  avg_lat=0
  [[ $total -gt 0 ]] && avg_lat=$((total_latency / total))
  echo "$model|pass_rate=${rate}%|passes=${passes}/${total}|avg_latency=${avg_lat}ms"
done
