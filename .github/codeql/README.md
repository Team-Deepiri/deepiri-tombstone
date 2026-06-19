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
Runs one analysis job per coding language in parallel:
- `cpp` — C bridge (`c/ollama_bridge.c`)
- `python` — small fallback helpers in `scripts/`

### Initialize CodeQL
Starts the CodeQL engine and loads `.github/codeql/codeql-config.yml`.

### Analyze
Executes queries and uploads results to GitHub Security.

## Config breakdown (`.github/codeql/codeql-config.yml`)

### `paths-ignore`
Excludes vendored toolchains, build outputs, generated LLVM IR, runtime reports, and docs.

## Maintenance examples

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
