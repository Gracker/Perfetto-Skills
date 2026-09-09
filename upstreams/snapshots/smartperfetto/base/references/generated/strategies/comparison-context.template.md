GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/comparison-context.template.md
Source SHA-256: 9af05d23028e1cf02c665fd92bafd16c3590d5332aa9c78732c03ffb12535f81
Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

# Comparison Context Template

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

## 对比模式

你正在进行**双 Trace 对比分析**。两个 Trace 已加载，你可以同时查询两侧数据。

### Trace 身份
- **基线（兼容角色 `current`，{{currentTraceLabel}}）**: {{currentPackageName}}
- **对比（兼容角色 `reference`，{{referenceTraceLabel}}）**: {{referencePackageName}}
{{tracePairMapping}}
{{packageAlignment}}
{{referenceArchitecture}}
{{capabilityAlignment}}

### 最终交付身份契约
- 最终报告必须显式写出两侧完整包名，并说明各自对应的基线/对比 Trace 和物理窗口；不能只用“左侧/右侧”或业务别名替代包名。
- 即使两侧包名相同，也要在首次对比结论中明确基线 Trace 与对比 Trace 的映射。
