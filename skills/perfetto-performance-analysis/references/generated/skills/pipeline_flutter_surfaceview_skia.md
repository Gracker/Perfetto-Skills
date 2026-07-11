GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/flutter_surfaceview_skia.skill.yaml
Source SHA-256: 4f3e9353512c115a63ada88248084eb7717909cfc5f0e72e30e0fc8ce64b6162
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# Flutter SurfaceView (Skia)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_flutter_surfaceview_skia
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: FLUTTER_SURFACEVIEW_SKIA
display_name: Flutter SurfaceView (Skia)
description: Flutter + Skia 引擎，运行时 Shader 编译 (Runtime Shader Compilation)
icon: flutter
family: flutter
doc_path: rendering_pipelines/flutter_surfaceview.md
s_article_ref: S10
four_features:
  producer_threads:
  - 1.ui
  - 1.raster
  - 1.io
  optional_producer_threads:
  - DartWorker*
  - io.flutter.*
  expected_layer_count: 1
  bufferqueue_path: ENGINE_TO_INDEPENDENT_SURFACE
  extra_rhythm_sources:
  - engine_animator_beginframe
deviation_anchors: engine_anchor_2_3_4_5_6_at_engine_threads_skia_backend
layer_signature: io.flutter.* surface 名（独立 layer）
subvariants_note: '文章 S10 的 Skia 后端路径——与 Impeller 是同一个 RenderMode.surface 的两种 backend。

  现代 Flutter 默认 Impeller，Skia 仍出现在：旧版本、特定配置、Impeller fallback 场景。

  '
skia_disadvantage: 'Skia 运行时 shader compilation：首次使用新 effect 触发 shader 编译，

  导致首帧/首场景卡顿。Trace 中 SkGpu / SkiaGpu 配合 GrShaderUtils 是典型信号。

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_skgpu
  slice_pattern: '*SkGpu*'
  weight: 35
- signal: has_skiagpu
  slice_pattern: '*SkiaGpu*'
  weight: 30
- signal: has_flutter_raster
  thread_pattern: '*raster*'
  weight: 10
- signal: has_flutter_ui_hint
  thread_pattern: '*ui*'
  weight: 8
- signal: has_dart_worker
  thread_pattern: DartWorker*
  weight: 18
- signal: has_flutter_jit
  slice_pattern: '*io.flutter*'
  weight: 12
exclude_if:
- slice_pattern: '*EntityPass*'
```

## Teaching model

```yaml
title: Flutter SurfaceView (Skia) 渲染管线
summary: 'Flutter 使用 Skia 渲染引擎，通过 SurfaceView 独立渲染。

  Skia 使用运行时 Shader 编译 (Runtime Shader Compilation)，首次使用新效果时可能有编译卡顿。

  在旧版本、特定配置或 Impeller fallback 场景中仍可能使用该模式，需重点关注 Shader 编译与光栅化耗时。

  '
mermaid: "sequenceDiagram\n  participant VA as VSync-app\n  participant UI as ui/main (Dart)\n  participant IO as 1.io\n \
  \ participant Raster as raster (Skia)\n  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as\
  \ SurfaceFlinger\n\n  Note over VA,SF: \U0001F4CD Flutter Frame Production (Skia)\n  VA->>UI: \U0001F514 VSync → BeginFrame\
  \ (常见)\n  activate UI\n  UI->>UI: Dart VM 执行 (build → layout → paint)\n  UI->>UI: 生成 Layer Tree\n  UI->>Raster: 提交 Layer\
  \ Tree\n  deactivate UI\n\n  activate Raster\n  Raster->>Raster: SkGpu::DrawLayers\n  Raster->>Raster: GPU 光栅化 (OpenGL/Vulkan)\n\
  \  Raster->>BQ: queueBuffer\n  deactivate Raster\n\n  VS->>SF: \U0001F514 VSync-sf\n  activate SF\n  SF->>SF: latchBuffer\n\
  \  SF->>SF: HWC Composite\n  deactivate SF\n\n  Note over IO: 1.io 线程负责图片解码\n  Note over VA,SF: ⚠️ Skia 运行时 Shader 编译可能导致首帧卡顿\n"
thread_roles:
- thread: ui / main / 1.ui
  role: Dart UI 线程
  description: 执行 Dart 代码，生成 Layer Tree；线程名依版本变化
- thread: raster / 1.raster
  role: Skia 光栅化
  description: 使用 Skia 光栅化
- thread: 1.io
  role: Flutter IO
  description: 资源加载
key_slices:
- name: SkGpu
  thread: raster / 1.raster
  description: Skia GPU 渲染提示信号
- name: Rasterizer
  thread: raster / 1.raster
  description: 光栅化操作提示信号
```

## Analysis guidance

```yaml
common_issues:
- id: shader_compilation
  name: Shader 编译卡顿
  description: 运行时 Shader 编译 (Runtime Shader Compilation) 导致首次使用卡顿
  detection_skill: jank_frame_detail
- id: ui_thread_overrun
  name: 1.ui 线程超 budget
  description: Dart build/layout/paint 过重；与 Impeller 路径相同。
  detection_skill: app_frame_production
- id: raster_thread_overrun
  name: 1.raster 线程超 budget（含 Skia 编译）
  description: 'GPU submission 重 / fence 等待 / Skia shader 首次编译。

    Skia 路径下 raster 线程超 budget 还可能因 shader 缓存未命中。

    '
  detection_skill: gpu_render_in_range
- id: skia_first_use_jank
  name: 首次使用新效果的 Shader 编译卡顿
  description: 'Skia 运行时编译 shader：首次使用某个 BlendMode / SkShader / RuntimeEffect 时触发编译。

    缓解：预热（precache shader）、SkSL warmup、降级到 Impeller。

    '
  detection_skill: jank_frame_detail
recommended_skills:
- scrolling_analysis
- jank_frame_detail
- gpu_analysis
- flutter_scrolling_analysis
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (Flutter 开始生产帧)
- pattern: ^1\.ui$
  match_by: name
  priority: 2
  reason: Dart UI 线程 (生产)
- pattern: ^1\.raster$
  match_by: name
  priority: 3
  reason: Skia 光栅化 (传输)
- pattern: io\.flutter
  match_by: name
  priority: 4
  reason: Flutter IO
- pattern: ^VSYNC-sf$
  match_by: name
  priority: 5.5
  reason: VSync (SurfaceFlinger 消费/合成)
- pattern: ^BufferTX
  match_by: name
  priority: 6
  reason: BufferTX (SurfaceFlinger 事务)
- pattern: ^[sS]urface[fF]linger
  match_by: name
  priority: 7
  reason: SurfaceFlinger (最终合成/显示)
  main_thread_only: true
```
