GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/arch-flutter.template.md
Source SHA-256: e9390b364cd97b5cb28319401df7c000e46e1dbf3b3f77d8b35cef2cfafe41e7
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

# Arch Flutter Template

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
### Flutter 分析注意事项
- **线程模型**：Flutter 使用 `N.ui` (UI/Dart)  和 `N.raster` (GPU raster) 线程替代标准 Android MainThread/RenderThread
- **帧渲染**：观察 `N.raster` 线程上的 `Rasterizer::DrawToSurfaces` slice，它是每帧 GPU 耗时的关键指标
- **Engine 差异**：Skia 引擎看 `SkCanvas*` slice；Impeller 引擎看 `Impeller*` slice
- **SurfaceView vs TextureView**：
  - **SurfaceView（单出图）**：1.ui → 1.raster → BufferQueue → SurfaceFlinger。Jank 来源在 1.ui/1.raster，不涉及 RenderThread
  - **TextureView（双出图）**：1.ui → 1.raster(光栅化) → JNISurfaceTexture(纹理桥接, trace 中显示为 `JNISurfaceTextu`) → RenderThread(updateTexImage + composite)。Jank 可能在 1.ui、1.raster 或 RenderThread updateTexImage，也需关注 JNISurfaceTexture 桥接开销
- **Jank 判断**：需同时看 `N.ui` (Dart 逻辑耗时) 和 `N.raster` (GPU raster 耗时)，任一超帧预算都会导致掉帧

### 结论必须包含的 Flutter 信息
- **渲染管线类型**：必须在结论概览中明确标注 SurfaceView（单出图）或 TextureView（双出图），并描述对应的渲染管线路径
- **Engine 类型**：标注 Impeller 或 Skia（如检测为 UNKNOWN，说明判断依据）
- **线程对应关系**：说明 1.ui/1.raster 线程与哪个进程对应
