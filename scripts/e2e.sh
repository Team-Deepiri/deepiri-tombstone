#!/usr/bin/env bash
# Run full e2e pipeline against a live Ollama instance
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODEL="${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
FIXTURE="${1:-fixtures/eval_prompts.txt}"

echo "=== deepiri-tombstone e2e ==="
echo "Model:   $MODEL"
echo "Fixture: $FIXTURE"

if ! command -v ollama >/dev/null 2>&1; then
  echo "ERROR: ollama not installed. Run ./scripts/install-deps.sh"
  exit 1
fi

if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
  echo "Pulling model $MODEL..."
  ollama pull "$MODEL"
fi

echo "=== Fixture validation ==="
bash scripts/validate_fixtures.sh "$FIXTURE"

echo "=== Eval run ==="
export DEEPIRI_TOMBSTONE_MODEL="$MODEL"
# Use the orchestrator if built, else simulate
if [[ -f bin/deepiri-tombstone-core ]]; then
  ./deepiri-tombstone eval "$MODEL" "$FIXTURE"
else
  echo "Orchestrator not built — running individual components:"
  while IFS='|' read -r prompt keyword; do
    [[ -z "$prompt" || "$prompt" =~ ^[[:space:]]*# ]] && continue
    echo "---"
    echo "PROMPT: $prompt"
    # 1. Tokenize
    echo "$prompt" | bash scripts/tokenize_fallback.sh
    # 2. Generate (curl to ollama)
    REQ=$(bash scripts/build_request_fallback.sh "$MODEL" "$prompt")
    echo "$REQ" > /tmp/dt_e2e_req.json
    RAW=$(curl -sf "http://${DEEPIRI_TOMBSTONE_HOST:-127.0.0.1:11434}/api/generate" \
      -d "$REQ" 2>/dev/null || echo '{"response":"ERROR"}')
    # 3. Parse
    echo "$RAW" | awk -f awk/parse_response.awk > /tmp/dt_e2e_parsed.txt 2>/dev/null
    RESPONSE=$(cat /tmp/dt_e2e_parsed.txt)
    # 4. Score
    bash scripts/score_fallback.sh 500 /tmp/dt_e2e_parsed.txt
    # 5. Audit
    echo "run-e2e-$$|$MODEL|$prompt|$RESPONSE|500|PASS" | bash scripts/audit_fallback.sh
    echo "RESPONSE: $RESPONSE"
    echo "KEYWORD:  ${keyword:-}"
  done < "$FIXTURE"
fi

echo "=== Reports ==="
ls -la reports/
echo ""
echo "Summary:"
cat reports/summary.txt 2>/dev/null || echo "(no summary yet)"
echo ""
echo "=== Done ==="
