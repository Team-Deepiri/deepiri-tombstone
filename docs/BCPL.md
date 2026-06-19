# BCPL request builder

File: `bcpl/build_request.b`
Binary: `bin/build_request`
Fallback: `scripts/build_request_fallback.sh`

Builds a JSON request body for Ollama's /api/generate endpoint.

Output: `{"model":"<name>","prompt":"<text>","stream":false}`

Requires cintsys (Martin Richards' BCPL) for native compilation.
Without BCPL, the Python-based fallback is used.
