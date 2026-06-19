# Module map

| Stage | Path | Role |
|-------|------|------|
| Orchestrator | `src/orchestrator/*.b` | CLI and eval loop |
| Bridge | `src/bridge/ollama_bridge.c` | Ollama HTTP + shared buffers |
| Tokenize | `src/tokenize/` | Word count / budget |
| Parse | `src/parse/response.awk` | JSON field extraction |
| Score | `src/score/score.f` | Running stats |
| Audit | `src/audit/ledger.cob` | Compliance ledger |
| Request | `src/request/build_request.b` | Generate API JSON |
| Transport | `src/transport/http_fallback.pl` | Backup HTTP client |

See [src/README.md](../src/README.md) for the full layout.
