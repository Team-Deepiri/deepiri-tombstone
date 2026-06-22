#!/usr/bin/env bash
# Quick evaluation with a single prompt — rich output with full pipeline
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODEL="${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
PROMPT="${1:-What is 2+2?}"
OUTPUT="${2:-text}"  # text, json, verbose

echo "=== Quick Eval ==="
echo "Model:  $MODEL"
echo "Prompt: $PROMPT"
echo ""

TIMESTAMP=$(date +%s%N)

# 1. Tokenize
echo "---[1/5] Tokenize ---"
echo "$PROMPT" | bash src/tokenize/fallback.sh

# 2. Build request
echo "---[2/5] Build Request ---"
REQ=$(bash src/request/fallback.sh "$MODEL" "$PROMPT")
echo "$REQ"

# 3. Generate
echo "---[3/5] Generate ---"
HOST="${DEEPIRI_TOMBSTONE_HOST:-127.0.0.1:11434}"
RAW=""
for attempt in 1 2 3; do
  RAW=$(curl -sf --max-time 120 "http://$HOST/api/generate" -d "$REQ" 2>/dev/null || true)
  if [[ -n "$RAW" ]]; then break; fi
  echo "  (retry $attempt)"
  sleep 1
done
TIMESTAMP2=$(date +%s%N)
LATENCY=$(( (TIMESTAMP2 - TIMESTAMP) / 1000000 ))

if [[ -z "$RAW" ]]; then
  echo "  ERROR: curl failed — is Ollama running on $HOST?"
  RAW='{"response":"(curl failed)"}'
fi

# 4. Parse
echo "---[4/5] Parse ---"
RESPONSE=$(echo "$RAW" | awk -f src/parse/response.awk 2>/dev/null || echo "(parse error)")
echo "$RESPONSE"

# 5. Score
echo "---[5/5] Score ---"
echo "$RESPONSE" > /tmp/dt_quick_response.txt
bash src/score/fallback.sh "$LATENCY" /tmp/dt_quick_response.txt

# Audit
echo "--- Audit ---"
runid="quick-$(date +%s)"
echo "$runid|$MODEL|$PROMPT|$RESPONSE|$LATENCY|PASS" | bash src/audit/fallback.sh

echo ""
echo "=== Summary ==="
echo "Prompt:   $PROMPT"
echo "Response: $RESPONSE"
echo "Latency:  ${LATENCY}ms"
echo "Length:   ${#RESPONSE} chars"
echo ""
echo "See reports/ for full audit trail"
