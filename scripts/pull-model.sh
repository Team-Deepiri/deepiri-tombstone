#!/usr/bin/env bash
# Pull an Ollama model (native CLI or Docker Compose service)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODEL="${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
MODEL="${1:-$MODEL}"

pull_via_docker() {
  local compose=(docker compose)
  if ! docker compose version >/dev/null 2>&1; then
    compose=(docker-compose)
  fi
  if ! "${compose[@]}" ps ollama 2>/dev/null | grep -qE 'running|Up'; then
    return 1
  fi
  "${compose[@]}" exec -T ollama ollama pull "$MODEL"
}

model_present() {
  if command -v ollama >/dev/null 2>&1; then
    ollama list 2>/dev/null | grep -qF "$MODEL"
    return
  fi
  curl -sf "http://${DEEPIRI_TOMBSTONE_HOST:-127.0.0.1:11434}/api/tags" \
    | grep -qF "$MODEL"
}

if model_present; then
  echo "Model $MODEL already available"
  exit 0
fi

echo "Pulling $MODEL (this may take a while)..."

if command -v ollama >/dev/null 2>&1; then
  ollama pull "$MODEL"
elif pull_via_docker; then
  :
else
  echo "ERROR: no ollama CLI and Docker ollama service not running."
  echo "Run ./setup.sh or: bash scripts/ollama-docker.sh up"
  exit 1
fi

if model_present; then
  echo "Pulled $MODEL"
else
  echo "ERROR: failed to pull $MODEL"
  exit 1
fi
