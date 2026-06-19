#!/usr/bin/env bash
# Quick test individual pipeline components
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

case "${1:-help}" in
  parse)
    echo '{"response":"hello world","done":true}' | awk -f awk/parse_response.awk
    ;;
  tokenize)
    echo "${2:-hello world}" | gforth -e "include forth/tokenize.fs" 2>/dev/null \
      || echo "${2:-hello world}" | bash scripts/tokenize_fallback.sh
    ;;
  score)
    echo "test response" > /tmp/dt_quick_response.txt
    if command -v gfortran >/dev/null 2>&1; then
      gfortran -o /tmp/dt_quick_score fortran/score.f 2>/dev/null
      /tmp/dt_quick_score "${2:-500}" /tmp/dt_quick_response.txt
    else
      bash scripts/score_fallback.sh "${2:-500}" /tmp/dt_quick_response.txt
    fi
    ;;
  audit)
    echo "${2:-run-001|llama3.2|test prompt|test response|1234|PASS}" \
      | bash scripts/audit_fallback.sh
    ;;
  build-request)
    bash scripts/build_request_fallback.sh "${2:-llama3.2}" "${3:-hello}"
    ;;
  http)
    perl perl/http_fallback.pl "${2:-llama3.2}" "${3:-hello}"
    ;;
  all)
    $0 parse
    $0 tokenize "hello world"
    $0 score 500
    $0 audit "run-001|llama3.2|test prompt|ok|1234|PASS"
    $0 build-request llama3.2 "hello"
    ;;
  help|*)
    echo "Usage: $0 <component> [args]"
    echo "Components: parse, tokenize, score, audit, build-request, http, all"
    ;;
esac
