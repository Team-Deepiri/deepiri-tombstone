# Style guide

## Shell scripts

- Use `#!/usr/bin/env bash`
- `set -euo pipefail` at the top
- Use `[[ ]]` for conditionals (not `[ ]`)
- Quote all variables: `"$var"`
- Use `$(cmd)` over backticks
- Prefer `printf` over `echo` for complex output
- Use `snake_case` for function names
- Use `UPPER_CASE` for environment variables
- Exit with meaningful codes (0 = success, 1 = general error)

## Languages

- **B**: Follow blang conventions, 2-space indent, `str_` prefix for string functions
- **C**: snake_case, K&R style braces
- **BCPL**: Upper case keywords, GET at top
- **Forth**: lowercase, space between words
- **Fortran**: Fixed format, columns 7-72 for code
- **COBOL**: Columns 8-72 for code, DIVISION/SECTION headers
- **AWK**: Use `exit N` for error codes
- **Perl**: `use strict; use warnings;`

## Makefile

- Use `$(CURDIR)` for absolute paths
- Fallback to shell scripts when compilers unavailable
- `.PHONY` for all non-file targets
- Alphabetical target order in help

## Commits

- Conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`, `ci:`
- One logical change per commit
- Imperative mood in subject line
