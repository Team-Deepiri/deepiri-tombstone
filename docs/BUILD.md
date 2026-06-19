# Build system

deepiri-tombstone uses a GNU Make-based build system with automatic fallback
when native compilers are unavailable.

## How it works

```
Source files → Makefile rules → bin/<component>
                ↓
         Shell fallback (when compiler not found)
```

The Makefile tries each native compiler first. If it's not installed,
the target copies a shell fallback script into `bin/`.

## Targets

| Target | Description |
|--------|-------------|
| `all` | Build everything |
| `clean` | Remove build artifacts |
| `dist` | Clean + all |
| `test` | Integration verification |
| `unit-test` | Component unit tests |
| `smoke-test` | Quick health check |
| `hooks` | Install git pre-commit hooks |
| `install-completion` | Install bash completion |
| `stats` | Project statistics |
| `check-deps` | Verify dependencies |
| `config` | Show configuration |
| `archive` | Archive reports |
| `watch` | Auto-rebuild on changes |
| `clean-all` | Remove all generated data |

## Vendor directory

`vendor/` contains local copies of blang and libb.a, downloaded by
`scripts/install-deps.sh`. The Makefile defaults to these vendored
paths, which can be overridden with environment variables:

```bash
make BLANG=/usr/bin/blang LIBB=/usr/lib/libb.a
```

## Fallback chain

| Component | Native | Fallback |
|-----------|--------|----------|
| Tokenizer | gforth | `scripts/tokenize_fallback.sh` |
| Scorer | gfortran | `scripts/score_fallback.sh` |
| Audit | gnucobol | `scripts/audit_fallback.sh` |
| Request | cintsys | `scripts/build_request_fallback.sh` |
| HTTP | perl | (one implementation) |
| Parse | awk | (one implementation) |
