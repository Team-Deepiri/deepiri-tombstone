# Development guide

## Prerequisites

See `scripts/install-deps.sh` or run it directly:
```bash
bash scripts/install-deps.sh
```

## Build

```bash
make             # full build
make help        # list targets
make components  # show pipeline components
make test        # run integration tests
make stats       # show project statistics
```

## Workflow

1. Make changes to a language component
2. Run `bash scripts/test_component.sh <component>` to test it
3. Run `bash scripts/verify_all.sh` for full integration check
4. Run `make` to verify the full build
5. Commit with conventional commit message

## Adding a new component

1. Create source file in the appropriate language directory
2. Add build target to Makefile (with fallback if applicable)
3. Add test to `scripts/verify_all.sh`
4. Add documentation in `docs/`
5. Add test fixtures if needed

## Testing without compilers

Each component has a shell fallback when the native compiler is not installed.
This lets you develop and test the pipeline without installing all language
toolchains.

## Conventional commits

```
feat:     new feature
fix:      bug fix
docs:     documentation
test:     testing
refactor: code restructuring
chore:    tooling, config, deps
ci:       CI/CD changes
```
