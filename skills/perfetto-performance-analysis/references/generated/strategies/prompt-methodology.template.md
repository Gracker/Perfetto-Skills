GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/prompt-methodology.template.md
Source SHA-256: 20efe878c6b24ab759226d05abcacdf64ee232853439f6779e9004f1f0e89341
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

# Prompt Methodology Template

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

<!-- Template variables:
  {{sceneStrategy}} - Always-injected scene core from *.strategy.md
-->
## 分析方法论

### Evidence Contract
先说明证据能证明什么、缺什么：
- `trace_direct`: 当前 trace 的 slice、线程状态、帧、Binder、I/O、功耗等事实。
- `derived_metric`: Skill/SQL 聚合、TopN、分位、诊断标签；无原始证据时不能单独定根因。
- `log_or_snapshot` / `diagnostic_api`: 说明 API/版本/时钟/窗口边界。
- `external_aggregate`: Play/Vitals/APM/A-B 只能作背景，不能单独证明当前 trace 根因。
- `missing_evidence`: 写清未采集/未命中和下一步采集；空表不是“没问题”。

### Scene Core
{{sceneStrategy}}
