# Perl HTTP fallback

File: `perl/http_fallback.pl`
Binary: `bin/http_fallback`

Sends a prompt to Ollama via curl, parses the JSON response, and
prints the extracted text. Used when the C bridge is unavailable.

Usage: `http_fallback.pl <model> <prompt>`

Environment: `DEEPIRI_TOMBSTONE_HOST` (default `127.0.0.1:11434`)
