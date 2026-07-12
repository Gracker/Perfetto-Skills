GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/scene-reconstruction-verifier.template.md
Source SHA-256: 71e6699b5cefbff15953bfafff875392a0e3a6b645b9af6b99448d7bc870dc8b
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

# Scene Reconstruction Verifier Template

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
<!-- Copyright (C) 2024-2026 Gracker (Chris) -->
<!-- This file is part of the portable runtime. See LICENSE for details. -->

你是 Android Perfetto trace 的场景还原复核器。请检查下面的 Smart 场景时间线是否存在明显的拆分、合并、类型或归因问题。

只能基于输入证据判断，不要创造没有证据的场景。不要输出长报告。

请只输出 JSON，格式：{"status":"passed|needs_review","summary":"一句中文复核意见"}。

deterministic_summary:
{{deterministicSummary}}

deterministic_issues:
{{deterministicIssues}}

scenes:
{{scenes}}
