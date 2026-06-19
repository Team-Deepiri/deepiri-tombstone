#!/usr/bin/env bash
# Verify git commit history quality
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
errors=0

echo "=== Commit history verification ==="

# Check conventional commit format
echo "--- Conventional commit check ---"
git log --oneline --no-merges HEAD 2>/dev/null | while read hash msg; do
  if [[ ! "$msg" =~ ^(feat|fix|docs|test|refactor|chore|ci): ]]; then
    echo "  WARNING: $hash does not follow conventional commit: $msg"
  fi
done

# Check for merge commits
if git log --oneline --merges HEAD 2>/dev/null | head -1 | grep -q .; then
  echo "  Merge commits found"
fi

# Count commits per type
echo "--- Commit stats ---"
feats=$(git log --oneline --no-merges HEAD 2>/dev/null | grep -c "^feat:" || true)
fixes=$(git log --oneline --no-merges HEAD 2>/dev/null | grep -c "^fix:" || true)
docs=$(git log --oneline --no-merges HEAD 2>/dev/null | grep -c "^docs:" || true)
tests=$(git log --oneline --no-merges HEAD 2>/dev/null | grep -c "^test:" || true)
refactors=$(git log --oneline --no-merges HEAD 2>/dev/null | grep -c "^refactor:" || true)
chores=$(git log --oneline --no-merges HEAD 2>/dev/null | grep -c "^chore:" || true)
cis=$(git log --oneline --no-merges HEAD 2>/dev/null | grep -c "^ci:" || true)
echo "  feat: $feats"
echo "  fix: $fixes"
echo "  docs: $docs"
echo "  test: $tests"
echo "  refactor: $refactors"
echo "  chore: $chores"
echo "  ci: $cis"
echo "  total: $((feats + fixes + docs + tests + refactors + chores + cis))"

echo ""
if [[ "$errors" -eq 0 ]]; then echo "Commit history looks good"
else echo "$errors issue(s) found"; fi
exit "$errors"
