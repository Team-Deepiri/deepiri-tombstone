#!/usr/bin/env bash
# Enhanced end-to-end pipeline against live Ollama with rich output and comparison
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODEL="${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
FIXTURE="${1:-fixtures/eval_prompts.txt}"
COMPARE="${2:-}"
OUTPUT="${3:-text}"  # text, json, jsonl, markdown

echo "=== deepiri-tombstone e2e ==="
echo "Model:   $MODEL"
echo "Fixture: $FIXTURE"
echo "Output:  $OUTPUT"

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not found" >&2
  exit 1
fi

# Validate fixture
bash scripts/validate_fixtures.sh "$FIXTURE" 2>&1 || echo "WARNING: fixture may have issues" >&2

echo "=== Eval run ==="
mkdir -p reports
rm -f reports/stats.dat reports/summary.txt reports/category_stats.txt reports/trend.dat reports/audit.ledger

total=0
pass=0
fail=0
lat_sum=0
start_time=$(date +%s)

if [[ "$OUTPUT" == "json" || "$OUTPUT" == "jsonl" ]]; then
  echo "["
  first=1
fi

if [[ "$OUTPUT" == "markdown" ]]; then
  echo "| # | Prompt | Response | Status | Latency |"
  echo "|---|--------|----------|--------|---------|"
fi

while IFS='|' read -r prompt keyword; do
  [[ -z "$prompt" || "$prompt" =~ ^[[:space:]]*# ]] && continue
  total=$((total + 1))
  
  if [[ "$OUTPUT" == "text" ]]; then
    echo "--- [$total] $prompt"
  fi
  
  # Tokenize
  token_result=$(echo "$prompt" | bash src/tokenize/fallback.sh 2>/dev/null)
  
  # Build request
  REQ=$(bash src/request/fallback.sh "$MODEL" "$prompt" 2>/dev/null)
  
  # Generate (with retry)
  RAW=""
  for attempt in 1 2 3; do
    RAW=$(timeout 120 curl -sf "http://${DEEPIRI_TOMBSTONE_HOST:-127.0.0.1:11434}/api/generate" \
      -d "$REQ" 2>/dev/null || true)
    if [[ -n "$RAW" ]]; then
      break
    fi
    sleep 1
  done
  
  t1=$(date +%s%N)
  LATENCY=0
  
  if [[ -z "$RAW" ]]; then
    RAW='{"response":"(generate failed)"}'
  else
    # Calculate latency
    LATENCY=$(( (t1 - start_time) / 1000000 ))
  fi
  
  # Parse
  RESPONSE=$(echo "$RAW" | awk -f src/parse/response.awk 2>/dev/null || echo "(parse error)")
  
  # Score (with category)
  CATEGORY=$(echo "$prompt" | awk '{
    if (/code/ || /function/ || /binary/ || /Python/ || /algorithm/) print "coding";
    else if (/capital/ || /history/ || /what is/ || /famous/ || /language/) print "knowledge";
    else if (/say/ || /respond/ || /return/ || /repeat/) print "instruction";
    else if (/if/ || /step/ || /think/ || /reason/ || /minutes/) print "reasoning";
    else if (/ignore/ || /pick/ || /how to/ || /tell me/) print "safety";
    else if (/hello/ || /hi/ || /haiku/) print "language";
    else print "general";
  }')
  
  bash src/score/fallback.sh "$LATENCY" /dev/null "$CATEGORY" 2>/dev/null <<< "$RESPONSE" || true
  
  # Check pass/fail
  STATUS="PASS"
  if [[ -z "$RESPONSE" ]]; then
    STATUS="FAIL"
  elif [[ -n "$keyword" ]]; then
    if ! grep -qi "$keyword" <<< "$RESPONSE" 2>/dev/null; then
      STATUS="FAIL"
    fi
  fi
  
  [[ "$STATUS" == "PASS" ]] && pass=$((pass + 1)) || fail=$((fail + 1))
  lat_sum=$((lat_sum + LATENCY))
  
  # Audit
  runid="e2e-$(date +%s)-${total}"
  echo "$runid|$MODEL|$prompt|$RESPONSE|$LATENCY|$STATUS" | bash src/audit/fallback.sh > /dev/null 2>&1 || true
  
  if [[ "$OUTPUT" == "text" ]]; then
    echo "  -> $RESPONSE [$STATUS] (${LATENCY}ms)"
  elif [[ "$OUTPUT" == "json" ]]; then
    [[ "$first" -eq 0 ]] && echo ","
    first=0
    printf '  {"prompt":"%s","response":"%s","status":"%s","latency_ms":%d}' \
      "$prompt" "$RESPONSE" "$STATUS" "$LATENCY"
  elif [[ "$OUTPUT" == "jsonl" ]]; then
    printf '{"prompt":"%s","response":"%s","status":"%s","latency_ms":%d}\n' \
      "$prompt" "$RESPONSE" "$STATUS" "$LATENCY"
  elif [[ "$OUTPUT" == "markdown" ]]; then
    short="${RESPONSE:0:60}"
    echo "| $total | ${prompt:0:40}... | $short... | $STATUS | ${LATENCY}ms |"
  fi
done < "$FIXTURE"

if [[ "$OUTPUT" == "json" ]]; then
  echo "]"
fi

end_time=$(date +%s)
duration=$((end_time - start_time))
pass_rate=$((total > 0 ? (pass * 100) / total : 0))
mean_lat=$((total > 0 ? lat_sum / total : 0))

echo ""
echo "=== Results ==="
echo "Total:     $total"
echo "Pass:      $pass"
echo "Fail:      $fail"
echo "Rate:      ${pass_rate}%"
echo "Avg Lat:   ${mean_lat}ms"
echo "Duration:  ${duration}s"

# Generate summary
bash src/score/fallback.sh "$mean_lat" /dev/null "summary" 2>/dev/null || true

echo ""
echo "=== Reports ==="
ls -la reports/ 2>/dev/null || echo "(no reports dir)"
