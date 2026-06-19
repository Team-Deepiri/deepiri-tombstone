#!/usr/bin/env bash
set -euo pipefail
MODEL="${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
ollama pull "$MODEL"
ollama list | grep -F "$MODEL" || { echo "model $MODEL not found"; exit 1; }
echo "pulled $MODEL"
