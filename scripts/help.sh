#!/usr/bin/env bash
# List all available commands and their descriptions
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "deepiri-tombstone CLI tools"
echo "==========================="
echo ""

declare -A DESCRIPTIONS
DESCRIPTIONS=(
  ["install-deps"]="Install all dependencies (system packages, blang, Ollama, BCPL)"
  ["pull-model"]="Pull an Ollama model for evaluation"
  ["validate_fixtures"]="Validate fixture file format"
  ["verify_all"]="Run full integration verification"
  ["test_all"]="Run all tests and checks"
  ["test_component"]="Test individual pipeline components"
  ["tokenize_fallback"]="Tokenize prompt (fallback when gforth unavailable)"
  ["score_fallback"]="Score response (fallback when gfortran unavailable)"
  ["audit_fallback"]="Audit record (fallback when gnucobol unavailable)"
  ["build_request_fallback"]="Build JSON request (fallback when cintsys unavailable)"
  ["e2e"]="Run end-to-end pipeline against live Ollama"
  ["benchmark"]="Benchmark pipeline component throughput"
  ["quick-eval"]="Quick single-prompt evaluation"
  ["check-deps"]="Check all dependencies"
  ["config"]="Show current configuration"
  ["stats"]="Show project statistics"
  ["summary"]="Show project summary dashboard"
  ["smoke-test"]="Quick project health check"
  ["watch"]="Watch source files and auto-rebuild"
  ["watch-eval"]="Watch eval progress in real-time"
  ["clean-all"]="Remove all generated data and artifacts"
  ["archive-reports"]="Archive old reports"
  ["compare"]="Compare two audit ledger files"
  ["export"]="Export eval results to JSON/CSV"
  ["report"]="Generate audit ledger report"
  ["search-prompts"]="Search fixture prompts by keyword"
  ["add-prompt"]="Add prompt to fixture file"
  ["gen-fixtures"]="Generate test prompts programmatically"
  ["install-hooks"]="Install git pre-commit hooks"
  ["pre-commit"]="Pre-commit hook script"
  ["pre-push"]="Pre-push hook script"
  ["update-changelog"]="Update CHANGELOG from git history"
  ["validate-requirements"]="Validate project requirements"
  ["validate-config"]="Validate configuration files"
  ["verify-scripts"]="Syntax-check all shell scripts"
  ["verify-commits"]="Check commit history quality"
  ["os-detect"]="Detect operating system"
  ["completion"]="Bash completion for deepiri-tombstone"
  ["run-b"]="Run B orchestrator wrapper"
  ["install-bcpl"]="Install BCPL compiler"
)

for cmd in "$@"; do
  if [[ -n "${DESCRIPTIONS[$cmd]:-}" ]]; then
    printf "  %-20s %s\n" "$cmd" "${DESCRIPTIONS[$cmd]}"
  else
    echo "  $cmd: (no description)"
  fi
done
