#!/usr/bin/env bash
# One-shot setup: deps, build, Ollama (Docker), model pull, smoke ping
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

export DEEPIRI_TOMBSTONE_HOST="${DEEPIRI_TOMBSTONE_HOST:-127.0.0.1:11434}"
export DEEPIRI_TOMBSTONE_MODEL="${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
export DEEPIRI_SKIP_OLLAMA_INSTALL=1

info()  { echo "==> $*"; }
warn()  { echo "!!  $*" >&2; }

info "deepiri-tombstone setup"
info "host=$DEEPIRI_TOMBSTONE_HOST model=$DEEPIRI_TOMBSTONE_MODEL"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is required. Install Docker, then re-run ./setup.sh"
  exit 1
fi

info "Installing build dependencies (native Ollama skipped — using Docker)"
bash scripts/install-deps.sh

if [[ ! -x vendor/llvm/usr/bin/clang-18 ]]; then
  info "Bootstrapping vendored blang/clang toolchain"
  bash scripts/bootstrap-toolchain.sh
fi

info "Building project"
make

info "Starting Ollama Docker service"
bash scripts/ollama-docker.sh up

info "Waiting for Ollama API"
ready=0
for _ in $(seq 1 45); do
  if curl -sf "http://${DEEPIRI_TOMBSTONE_HOST}/api/tags" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
if [[ "$ready" -ne 1 ]]; then
  warn "Ollama API not ready yet — check: docker compose logs ollama"
  exit 1
fi

info "Pulling model ${DEEPIRI_TOMBSTONE_MODEL}"
bash scripts/pull-model.sh "${DEEPIRI_TOMBSTONE_MODEL}"

info "Smoke test"
./deepiri-tombstone ping

info "Setup complete"
echo ""
echo "  ./deepiri-tombstone ask ${DEEPIRI_TOMBSTONE_MODEL} \"Say hello\""
echo "  ./deepiri-tombstone eval ${DEEPIRI_TOMBSTONE_MODEL}"
echo "  docker compose logs -f ollama    # watch Ollama"
echo "  bash scripts/ollama-docker.sh down"
