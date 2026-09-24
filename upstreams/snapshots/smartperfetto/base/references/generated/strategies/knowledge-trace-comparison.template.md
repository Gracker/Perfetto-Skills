GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-trace-comparison.template.md
Source SHA-256: 3927000a927da084e0b47ad8589675897eb8ee670799356db2af04a06692fe48
Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

# Knowledge Trace Comparison Template

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

## Trace comparison evidence

Resolve the user's baseline/comparison labels to the supplied trace identities
and pane aliases. State the full package/process names and windows used. Process
names, startup IDs and timestamps may differ: select the matching workload on
each side rather than copying a local ID or absolute time to the other trace.

Compare matching definitions, units, denominators, event populations and capture
coverage. A successful capability probe establishes comparable availability;
missing or unprobed capabilities remain unknown. Show baseline, comparison and
the delta direction for supported metrics. Missing is not zero, and a zero or
missing baseline does not support percentage change. Separate absolute delta,
relative change and share of the measured window.

For stored-result comparisons, use the normalized snapshot metrics and their
original provenance. Do not recover numbers from report prose or treat missing
dimensions as zero. Retain missingness and follow the current evidence-access
policy rather than silently querying raw traces to fill gaps.

Explain each material difference using aligned evidence and relevant system or
application context. A percentage threshold or two different measurements alone
does not prove a cause; retain alternatives, confounders and unsupported links.
