# Contributing

Perfetto Skills develops independently while importing selected SmartPerfetto
analysis knowledge and official Perfetto substrate through pinned, explicit
sync workflows.

## Before changing analysis content

1. Decide whether the change is native Perfetto-Skills work, a reviewed local
   overlay, or a SmartPerfetto import.
2. Add a failing project-owned real-trace assertion before changing local SQL.
3. Never hand-edit files marked `GENERATED FILE`; use the base/compiler/overlay
   workflow in `docs/maintenance/upstream-sync.md`.
4. Run the cross-repository impact checker and record its decision.
5. Run the complete independent gate.

```bash
uv sync --extra dev
uv run python tools/verify.py
```

During iteration, use the applicable static, unit, or selected-test command in
[local verification](docs/maintenance/verification.md). The default command
above remains the complete gate before push; scoped checks and offline smoke
do not replace it. Behavior corrections need focused regression coverage;
documentation-only changes do not need an artificial failing test.

Keep the main `SKILL.md` concise and place detailed domain knowledge in directly
linked references.
