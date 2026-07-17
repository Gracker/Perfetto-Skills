GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/arch-webview.template.md
Source SHA-256: b8a937586f62b7401f1fcf7071de354b108be6a7dcbb8f9f72157215451321f6
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

# Arch Webview Template

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
### WebView 分析注意事项
- **渲染线程**：GL Functor 模式下 WebView 的 DrawGL 在 App RenderThread 中执行（是帧耗时的重要组成部分）；SurfaceControl 模式下有独立的 Viz Compositor 线程，不经过 RenderThread
- **Surface 类型**：GLFunctor (传统) vs SurfaceControl (现代)，后者性能更好
- **JS 执行**：观察 V8 相关 slice（`v8.run`, `v8.compile`）来定位 JS 瓶颈
- **帧渲染**：WebView 帧不走 Choreographer 路径，需通过 SurfaceFlinger 消费端判断掉帧
