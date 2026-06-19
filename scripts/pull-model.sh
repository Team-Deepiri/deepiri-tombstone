#!/usr/bin/env bash
# Pull an Ollama model for evaluation
set -euo pipefail

MODEL="${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
MODEL="${1:-$MODEL}"

if ! command -v ollama >/dev/null 2>&1; then
  echo "ERROR: ollama not installed. Run ./scripts/install-deps.sh"
  exit 1
fi

if ollama list 2>/dev/null | grep -qF "$MODEL"; then
  echo "Model $MODEL already pulled"
  exit 0
fi

echo "Pulling $MODEL (this may take a while)..."
ollama pull "$MODEL"

if ollama list | grep -qF "$MODEL"; then
  echo "Pulled $MODEL"
else
  echo "ERROR: failed to pull $MODEL"
  exit 1
fi
