#!/usr/bin/env bash
# Show project statistics
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== deepiri-tombstone stats ==="
echo "Commits:  $(git rev-list --count HEAD 2>/dev/null || echo 0)"
echo "Branches: $(git branch -a | wc -l)"
echo "Contributors: $(git log --format='%an' 2>/dev/null | sort -u | wc -l)"
echo ""
echo "=== Lines of code ==="
for lang in "B (blang)" "C" "BCPL" "Forth" "Fortran" "COBOL" "AWK" "Perl" "Shell" "Makefile"; do
  case "$lang" in
    "B (blang)")   count=$(wc -l < b/*.b 2>/dev/null || echo 0) ;;
    "C")           count=$(wc -l < c/*.c 2>/dev/null || echo 0) ;;
    "BCPL")        count=$(wc -l < bcpl/*.b 2>/dev/null || echo 0) ;;
    "Forth")       count=$(wc -l < forth/*.fs 2>/dev/null || echo 0) ;;
    "Fortran")     count=$(wc -l < fortran/*.f 2>/dev/null || echo 0) ;;
    "COBOL")       count=$(wc -l < cobol/*.cob 2>/dev/null || echo 0) ;;
    "AWK")         count=$(wc -l < awk/*.awk 2>/dev/null || echo 0) ;;
    "Perl")        count=$(wc -l < perl/*.pl 2>/dev/null || echo 0) ;;
    "Shell")       count=$(wc -l < scripts/*.sh 2>/dev/null || echo 0) ;;
    "Makefile")    count=$(wc -l < Makefile 2>/dev/null || echo 0) ;;
  esac
  printf "  %-15s %s lines\n" "$lang" "$count"
done
echo ""
echo "=== Files ==="
git ls-files 2>/dev/null | wc -l
echo "total tracked"
