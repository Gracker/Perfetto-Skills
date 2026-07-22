GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/comparison-context-en.template.md
Source SHA-256: e909f9da3dda33a089edf10c2022932117fc7407c014d9364805b55c9770ddd8
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

# Comparison Context En Template

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
<!-- Copyright (C) 2024-2026 Gracker (Chris) | the portable runtime -->

## Comparison mode

You are performing a **dual-trace comparison**. Both traces are loaded and may be queried independently.

### Trace identity
- **{{currentTraceLabel}}**: {{currentPackageName}}
- **{{referenceTraceLabel}}**: {{referencePackageName}}
{{tracePairMapping}}
{{packageAlignment}}
{{referenceArchitecture}}
{{capabilityAlignment}}

### Final delivery identity contract
- The final report must explicitly state the full package name for both sides and map each package to its trace side; do not replace package names with only left/right, current/reference, or business aliases.
- Even when both package names are identical, state the current-trace and reference-trace mapping in the first comparison conclusion.
