#!/usr/bin/env bash
# Manage Ollama via Docker Compose for deepiri-tombstone
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE=(docker compose)
if ! docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
fi

cmd="${1:-up}"
shift || true

case "$cmd" in
  up|start)
    if ! command -v docker >/dev/null 2>&1; then
      echo "ERROR: docker not installed"
      exit 1
    fi
    "${COMPOSE[@]}" up -d ollama "$@"
    ;;
  down|stop)
    "${COMPOSE[@]}" stop ollama "$@" 2>/dev/null || true
    ;;
  restart)
    "${COMPOSE[@]}" restart ollama "$@"
    ;;
  logs)
    "${COMPOSE[@]}" logs -f ollama "$@"
    ;;
  status|ps)
    "${COMPOSE[@]}" ps ollama "$@"
    ;;
  *)
    echo "usage: $0 {up|down|restart|logs|status}"
    exit 1
    ;;
esac
