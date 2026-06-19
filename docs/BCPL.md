# BCPL request builder

File: `src/request/build_request.b`
Binary: `bin/build_request`
Fallback: `src/request/fallback.sh`

Builds a JSON request body for Ollama's /api/generate endpoint.

Output: `{"model":"<name>","prompt":"<text>","stream":false}`

Requires cintsys (Martin Richards' BCPL) for native compilation.
Without BCPL, the Python-based fallback is used.
