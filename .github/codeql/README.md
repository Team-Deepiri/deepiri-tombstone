# CodeQL Setup for deepiri-tombstone

This folder contains the CodeQL configuration for repository-level security scanning.

## What each file does

- `.github/workflows/codeql.yml`
  - Defines when scans run and how GitHub Actions executes CodeQL.
- `.github/codeql/codeql-config.yml`
  - Defines what folders to include and ignore during analysis.

## Workflow breakdown (`.github/workflows/codeql.yml`)

### `name: CodeQL`
The display name in the Actions tab.

### `on.pull_request.branches` and `on.push.branches`
Runs scans when PRs target `main` or `dev`, and when commits are pushed to `main` or `dev`.

### `permissions`
Uses least-privilege permissions. `security-events: write` is required so CodeQL can upload findings.

### `strategy.matrix.language`
Runs one analysis job for the C bridge (`src/bridge/ollama_bridge.c`). Shell/Python fallbacks are excluded because they are not primary security surfaces and Python sources are not present as standalone modules.

### Initialize CodeQL
Starts the CodeQL engine and loads `.github/codeql/codeql-config.yml`.

### Analyze
Executes queries and uploads results to GitHub Security.

## Config breakdown (`.github/codeql/codeql-config.yml`)

### `paths-ignore`
Excludes vendored toolchains, build outputs, generated LLVM IR, runtime reports, and docs.

## Prerequisites

GitHub Advanced Security (code scanning) must be enabled for `Team-Deepiri/deepiri-tombstone`
in **Settings → Code security and analysis → Code scanning**. Without it, the CodeQL
workflow completes analysis locally but cannot upload results.

### Add a new language
Edit matrix in `.github/workflows/codeql.yml`:
```yaml
language: [cpp, python, go]
```

### Exclude another generated folder
Add a glob to `paths-ignore`, for example:
```yaml
- '**/generated/**'
```
