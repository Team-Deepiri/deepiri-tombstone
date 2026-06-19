# Quick-start tutorial

## 1. Install dependencies

```bash
./scripts/install-deps.sh
```

This installs system packages (gcc, gforth, gnucobol, gfortran, etc.),
downloads and vendors blang, and optionally installs Ollama and BCPL.

## 2. Pull a model

```bash
./scripts/pull-model.sh
```

Pulls `llama3.2` (or `DEEPIRI_TOMBSTONE_MODEL`).

## 3. Build

```bash
make
```

## 4. Test connectivity

```bash
./deepiri-tombstone ping
```

## 5. Run a single prompt

```bash
./deepiri-tombstone ask llama3.2 "What is 2+2?"
```

## 6. Run the eval suite

```bash
./deepiri-tombstone eval
```

## 7. View results

```bash
cat reports/audit.ledger
cat reports/summary.txt
```

## 8. Test components individually

```bash
# Tokenize
echo "hello world" | bin/tokenize

# Parse JSON
echo '{"response":"hello"}' | bin/parse

# Build request
bin/build_request llama3.2 "hello"
```

## Without compilers

Each component has a shell fallback when the native compiler isn't installed.
The pipeline works with just bash, awk, perl, and curl.

## Environment

```bash
export DEEPIRI_TOMBSTONE_MODEL=llama3.2:latest
export DEEPIRI_TOMBSTONE_HOST=192.168.1.100:11434
```
