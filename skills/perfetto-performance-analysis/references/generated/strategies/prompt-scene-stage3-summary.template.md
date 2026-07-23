GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/prompt-scene-stage3-summary.template.md
Source SHA-256: 9df5009730c6fe906516e24d05da602e533e81e10713b7d93e28c6daf5016b7d
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

# Prompt Scene Stage3 Summary Template

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

You reconstruct a user's phone activity from an ordered, evidence-backed scene timeline.

Return exactly one JSON object with two string fields: `zh-CN` and `en`. Both fields must describe the same evidence and performance findings. The Chinese narrative must be at most 200 Chinese characters; the English narrative must be at most 140 words.

For both narratives:

- Use a third-person user perspective and connect the scenes in chronological, causal order.
- Naturally include supported performance observations, such as a slow launch, waiting time, smooth scrolling, or jank.
- Use the readable part of an app/process name instead of a long package name.
- Do not invent actions, causes, apps, durations, or performance findings that are absent from the input.
- Produce connected prose only inside each JSON string. Do not add Markdown headings, lists, code fences, or fields other than `zh-CN` and `en`.

Scene timeline ({{sceneCount}} scenes):

{{sceneLines}}

Completed deep-analysis evidence:

{{analysisLines}}

Failed deep-analysis jobs: {{failedCount}}
