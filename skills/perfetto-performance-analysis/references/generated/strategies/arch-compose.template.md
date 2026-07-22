GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/arch-compose.template.md
Source SHA-256: 6a46163bb5da7bba10ce66b7617c3f8a87851185766c0a8221e185e5e05308cb
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

# Arch Compose Template

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

<!-- No template variables — static content -->
### Jetpack Compose 分析注意事项
- **Recomposition**：关注 `Recomposer:recompose` slice 频率和耗时，频繁重组是性能杀手
- **LazyList**：`LazyColumn`/`LazyRow` 的 `prefetch` 和 `compose` 子 slice 影响滑动流畅度
- **Hybrid View**：如果 isHybridView=true，传统 View 和 Compose 混合渲染，需关注 `choreographer#doFrame` 中的 Compose 耗时
- **State 读取**：过多的 State 读取（尤其在 Layout 阶段）会触发不必要的重组
- **线程模型**：与标准 Android 相同（MainThread + RenderThread），但 Compose 的 Layout/Composition 阶段在 MainThread
