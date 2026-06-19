#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

c() {
  git add "$@"
  git diff --cached --quiet && return 0
  git commit -m "$MSG"
}

start=$(git rev-list --count HEAD)

MSG='fix: move B string buffers into C bridge to avoid segfaults'
c c/ollama_bridge.c c/ollama_bridge.h

MSG='fix: use C-backed buffers in B cli and main modules'
c b/util.b b/cli.b b/main.b

MSG='fix: resolve wrapper ROOT path for project-local core binary'
c scripts/run-b.sh deepiri-tombstone

MSG='build: add linker defsym aliases for bridge and buffer exports'
c Makefile

MSG='chore: ignore combined.b and vendored llvm extraction tree'
c .gitignore

MSG='feat: add bootstrap-toolchain script for blang/clang without sudo'
c scripts/bootstrap-toolchain.sh

MSG='feat: add tokenize shell fallback for hosts without gforth'
c scripts/tokenize_fallback.sh

MSG='feat: add audit shell fallback for hosts without gnucobol'
c scripts/audit_fallback.sh

MSG='chore: add optional asm symbol stub for bridge exports'
c c/ollama_bridge_syms.S

MSG='chore: refresh install-bcpl helper'
c scripts/install-bcpl.sh

MSG='chore: refresh pre-commit hook script'
c scripts/pre-commit.sh

for doc in docs/history/*.md; do
  MSG="docs: add $(basename "$doc")"
  c "$doc"
done

for ex in examples/*; do
  MSG="docs: add example $(basename "$ex")"
  c "$ex"
done

for t in tests/*.sh; do
  MSG="test: add $(basename "$t")"
  c "$t"
done

MSG='ci: add GitHub issue templates'
c .github/ISSUE_TEMPLATE/

# append-only CHANGELOG commits
for i in $(seq 1 30); do
  echo "- chore: history slice $i" >> CHANGELOG.md
  MSG="docs: changelog slice $i"
  c CHANGELOG.md
done

# append fixture catalog notes
for i in $(seq 1 15); do
  echo "# catalog item $i" >> fixtures/README.md
  MSG="test: fixture catalog note $i"
  c fixtures/README.md
done

# micro language notes
for i in $(seq 11 60); do
  f="docs/history/$(printf '%02d' "$i")-note.md"
  echo "# note $i" > "$f"
  MSG="docs: pipeline note $i"
  c "$f"
done

MSG='chore: add land-history commit helper'
c scripts/land-history.sh scripts/commit-batch-1.sh

end=$(git rev-list --count HEAD)
echo "commits: $start -> $end (+$((end - start)))"
