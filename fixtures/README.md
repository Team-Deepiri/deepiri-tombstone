# Fixture format

Each non-empty, non-comment line:

```
PROMPT|KEYWORD
```

- `PROMPT` — sent to Ollama
- `KEYWORD` — optional pass check (case-insensitive substring match in response)

Lines starting with `#` are ignored.
# catalog item 1
# catalog item 2
# catalog item 3
