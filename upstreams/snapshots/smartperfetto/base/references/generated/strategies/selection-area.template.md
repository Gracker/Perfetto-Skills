GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/selection-area.template.md
Source SHA-256: ce1ecbde75384022d028e1025ca885e1984539d80131f57e7d25dcfedd3d0aee
Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

# Selection Area Template

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

## 用户选区上下文

用户当前问题带有一个明确的时间范围 scope（来源: {{sourceLabel}}）：
- **起始时间:** {{startNs}} ns
- **结束时间:** {{endNs}} ns
- **持续时间:** {{durationMs}} ms
- **选中 Track 数:** {{trackCount}}{{trackSummary}}

**分析约束:**
- 这些字段只定义时间/Track 身份，不是 Trace 事实；名称、进程、线程和指标必须由后端工具查询后才能作为证据
- 指标由用户问题决定，核心查询限制在该区间；全局数据只能作为显式对照
- 持续时间表使用 overlap clipping：`ts < {{endNs}} AND ts + dur > {{startNs}}`；区间贡献为 `MIN(ts + dur, {{endNs}}) - MAX(ts, {{startNs}})`
