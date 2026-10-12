# Local verification

Use Python 3.11+ and `uv sync --extra dev`. Normal verification is independent
of SmartPerfetto and uses this repository's checksum-pinned real-trace pack
and locked official trace processor.

## Choose the check for iteration

| Command | Coverage | Real-trace preparation |
| --- | --- | --- |
| `uv run python tools/verify.py --tier static` | Upstream locks, compiled output drift, all query metadata/SQL checks, public Skill validation | None |
| `uv run python tools/verify.py --tier unit` | Static checks and every unit test | None |
| `uv run python tools/verify.py --tier unit --test tests.unit.test_verify` | Static checks and named unit module (or class/method) | None |
| `uv run python tools/verify.py --test tests.integration.test_fixture_manifest` | Static checks and named real-trace tests | Full pinned fixture pack and processor |
| `uv run python tools/verify.py --offline` | Static checks and test discovery using committed smoke only | Pinned processor and smoke checksum |
| `uv run python tools/verify.py` | Static checks, every unit/integration test, all declared fixture assertions | Full pinned fixture pack and processor |

Repeat `--test` for additional qualified targets. Unknown or empty selections
fail. Integration targets require the full tier; `--offline` and `--fixtures`
apply only to that tier. Do not use an integration check's skips as evidence
for an unavailable fixture.

A selection containing only unit tests skips real-trace preparation even at
the default tier. Selecting any integration target prepares and verifies the
owned traces; there is no filename-to-fixture heuristic that can omit coverage.

Static and unit tiers clear inherited trace/SmartPerfetto test configuration
and never download or prepare fixtures or a processor. They still inspect the
committed manifest, locks, compiler output, and query contracts. Full test
coverage and per-file checksum verification remain owned by the default gate.
Semantic fixture assertions execute once in the integration suite rather than
again through `validate_all_queries.py --execute`.
The full gate checks locks, compiler output, and static queries before preparing
real traces, so a static failure does not trigger unnecessary downloads or
fixture work.

## Before landing

Run the default command once on the final behavior-changing candidate before
push. A scoped check reports `complete_gate: false`; it does not replace this
step. Offline smoke also reports incomplete coverage. When a failure changes
source or leaves a risk unresolved, rerun the affected checks and final gate.
Do not rerun an unchanged successful gate merely to duplicate evidence.

Use `--fixtures PATH` to provide the full pack explicitly; hashes must match
the owned manifest. `PERFETTO_TEST_JOBS=1` bounds concurrent real-trace query
processes on constrained machines; the default is at most eight workers.
Processor identity (version, commit, RPC API) is checked before real queries.

`--smartperfetto PATH` adds explicit pinned import/catalog drift checks to the
selected tier. It is needed only for synchronization work and does not add a
runtime dependency. Follow [upstream synchronization](upstream-sync.md) for
cross-repository impact decisions, generated assets, and local SQL red-green
workflow.
