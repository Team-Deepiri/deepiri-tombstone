#!/usr/bin/env bash
# Update CHANGELOG.md with latest commit info
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION=$(cat VERSION 2>/dev/null || echo "0.0.0")
DATE=$(date +%Y-%m-%d)
COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo 0)
CHANGELOG="CHANGELOG.md"

echo "Updating $CHANGELOG for version $VERSION ($COMMITS commits)"

# Create or update the changelog
cat > "$CHANGELOG" <<EOF
# Changelog

## [$VERSION] — $DATE

### Added
$(git log --oneline --no-merges HEAD 2>/dev/null | while read hash msg; do
  case "$msg" in
    feat:*) echo "- $msg" ;;
    docs:*) echo "- $msg" ;;
    test:*) echo "- $msg" ;;
    ci:*) echo "- $msg" ;;
  esac
done)

### Fixed
$(git log --oneline --no-merges HEAD 2>/dev/null | while read hash msg; do
  case "$msg" in
    fix:*) echo "- $msg" ;;
    refactor:*) echo "- $msg" ;;
    chore:*) echo "- $msg" ;;
  esac
done)

### Commits
Total: $COMMITS

$(git log --oneline --no-merges HEAD 2>/dev/null)
EOF

echo "Updated $CHANGELOG"
