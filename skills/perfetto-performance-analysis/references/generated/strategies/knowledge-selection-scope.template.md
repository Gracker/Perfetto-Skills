GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-selection-scope.template.md
Source SHA-256: a8d55c6fce3dfe2d7cd64aac27b38a033fbf1b09f568927e07256467226a1e5f
Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

# Knowledge Selection Scope Template

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

## Selection identity and measurement scope

An event ID, track URI, UI label or selected interval is a lookup input, not a
verified observation. Resolve the event's actual table, process/thread instance
and time boundaries from permitted evidence. FrameTimeline IDs and ordinary
slice IDs are different namespaces; ambiguous matches remain ambiguous.

Follow the user's question and selected scope. Wider context can explain a
dependency but cannot replace the selected target. Under existing-only access,
missing identity or measurements remain unknown; a selection grants no new read.

Use half-open intervals and overlap-based clipping for duration attribution.
Retain unfinished/negative durations as explicit limitations. Selection summaries
need their denominator and coverage. Overlapping parent/child durations cannot
be added, and exclusive wall time is not automatically CPU or recoverable time.

For frame questions, distinguish expected/actual app-frame timing from compositor
presentation, and bind frame tokens, layer and process before joining them. An
absent jank flag or empty thread_state query does not by itself resolve every
question about that frame. Explain the missing capture or unsupported mechanism
without silently switching targets or broadening the measurement window.
