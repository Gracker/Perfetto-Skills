# Native source and reviewed overlays

`skills/`, `strategies/`, and `sql/` are reserved for Perfetto-Skills-native
assets with no upstream base. IDs must not collide with the immutable imported
base; adding a native asset also requires compiler/index support and tests.

`overrides/` contains full-file replacements for imported assets. Each JSON
descriptor follows `overrides/schema.json`, pins the exact base/replacement
hashes, explains the divergence, and records whether it should be proposed
upstream. SQL overlays additionally require owned real-trace regression IDs and
the stable failure signature observed against the immutable base.

Never edit `skills/perfetto-performance-analysis/references/generated/`
directly. First add an assertion that fails against the base, then add the
replacement and confirm it passes:

```bash
uv run python -m unittest tests.integration.test_local_sql_overlays
uv run python tools/compile_skill.py --check
uv run python tools/validate_all_queries.py
uv run python tools/verify.py
```

The compiler updates the affected query descriptor hash when SQL is replaced
and fails unless exactly one descriptor owns that path. After an upstream sync,
a changed base hash makes the overlay stale; review and re-run both base and
replacement regressions before updating the expected hash.
