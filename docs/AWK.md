# AWK JSON parser

File: `src/parse/response.awk`
Binary: `bin/parse`

Reads Ollama /api/generate JSON from stdin and extracts the `"response"`
field, handling escape sequences (`\n`, `\t`, `\r`, `\"`, `\\`, `\/`).

Exit codes:
- 0: success
- 1: no `"response"` key found
- 2: response value is not a string
- 3: unterminated string
