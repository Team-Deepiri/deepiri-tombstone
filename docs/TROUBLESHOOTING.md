# Troubleshooting

## Build fails: "blang not found"

Run `./scripts/install-deps.sh` to vendor blang into `vendor/blang` and `vendor/libb.a`.

## Build fails: "clang not found"

The Makefile expects a vendored clang at `vendor/llvm/usr/bin/clang-18`. Run `./scripts/bootstrap-toolchain.sh` if available, or set `CC` and `CLANG` to your system compiler:

```bash
make CLANG=clang-18 CC=gcc
```

## Audit: "AUDIT FAIL"

Check `reports/audit.ledger` is writable. Run `mkdir -p reports` and `touch reports/audit.ledger`.

## Score: no summary

The scorer needs `reports/stats.dat` to exist. The first run creates it. If it's missing, run a dummy score:

```bash
bash src/score/fallback.sh 0 /dev/null
```

## Forth: gforth not found

The tokenizer falls back to `src/tokenize/fallback.sh` automatically. Install gforth for the real thing:

```bash
sudo apt-get install gforth
```

## COBOL: cobc not found

Audit falls back to `src/audit/fallback.sh`. Install gnucobol for the native binary:

```bash
sudo apt-get install gnucobol
```

## Perl: missing JSON module

The Perl fallback parses JSON manually with regex — no module required.

## Ollama connection refused

Ensure Ollama is running: `ollama serve` or check the systemd service. Set `DEEPIRI_TOMBSTONE_HOST` if Ollama is on a different host.
