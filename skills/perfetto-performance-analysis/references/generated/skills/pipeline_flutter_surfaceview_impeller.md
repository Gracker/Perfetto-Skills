GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/flutter_surfaceview_impeller.skill.yaml
Source SHA-256: b08301d7024ffb2cb00c1bda6ee04e5bbcf5f992a01650564b66511d3a9225d4
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# Flutter SurfaceView (Impeller)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_flutter_surfaceview_impeller
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: FLUTTER_SURFACEVIEW_IMPELLER
display_name: Flutter SurfaceView (Impeller)
description: Flutter + Impeller，引擎常见于 SurfaceView render mode
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
deviation_anchors: engine_anchor_2_3_4_5_6_at_engine_threads
layer_signature: io.flutter.* surface 名（独立 layer）
subvariants_note: '文章 S10 的 Flutter SurfaceView 子变种：

  - FLUTTER_SURFACEVIEW（surface 模式，Impeller 或 Skia 后端）— 当前 ID 覆盖 Impeller

  - FLUTTER_TEXTUREVIEW（texture 模式，回宿主，单 layer）— FLUTTER_TEXTUREVIEW 覆盖

  - FLUTTER_IMAGVIEW_HC_OVERLAY / FLUTTER_HC_OVERLAY_PLATFORMVIEW（Hybrid Composition / PlatformView）— Phase E 拆分

  - FLUTTER_TEXTUREVIEW_PLATFORMVIEW（PlatformView TextureLayer 路径）— Phase E 拆分

  '
impeller_advantage: 'Impeller 预编译 shader/pipeline，消除 Skia 时代的运行时 shader compilation jank。

  Android 上 Impeller 默认 Vulkan backend，不支持时回退 OpenGL ES。

  '
known_traps: '- PlatformView 策略（VD/HC/TLHC/HCPP）默认选择随版本变化，不能假设固定

  - 透明背景强制 texture 模式（SurfaceView 无法透明混合）— 此时不属于此 ID

  - Flutter 双线程任一超 budget 都是 jank，不能只看 raster

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_impeller
  slice_pattern: '*Impeller*'
  weight: 45
- signal: has_entity_pass_hint
  slice_pattern: '*EntityPass*'
  weight: 20
- signal: has_flutter_raster
  thread_pattern: '*raster*'
  weight: 12
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
- slice_pattern: '*SkGpu*'
- slice_pattern: '*SkiaGpu*'
```

## Teaching model

```yaml
title: Flutter SurfaceView (Impeller) 渲染管线
summary: 'Flutter 使用 Impeller 渲染引擎，通过 SurfaceView 独立渲染。

  在 Android 上 Impeller 常使用 Vulkan（不支持时也可能回退到 OpenGL ES 路径），

  通过更可预测的 shader/pipeline 建立流程减少 Skia 时代的运行时编译卡顿。

  '
mermaid: "sequenceDiagram\n  participant VA as VSync-app\n  participant UI as ui/main (Dart)\n  participant IO as 1.io\n \
  \ participant Raster as raster\n  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\
  \n  Note over VA,SF: \U0001F4CD Flutter Frame Production (Impeller)\n  VA->>UI: \U0001F514 VSync → BeginFrame (常见)\n  activate\
  \ UI\n  UI->>UI: Dart VM 执行 (build → layout → paint)\n  UI->>UI: 生成 Layer Tree\n  UI->>Raster: 提交 Layer Tree\n  deactivate\
  \ UI\n\n  activate Raster\n  Raster->>Raster: Impeller raster / draw passes\n  Raster->>Raster: Vulkan 或 OpenGL ES GPU 光栅化\n\
  \  Raster->>BQ: queueBuffer\n  deactivate Raster\n\n  Note over BQ,SF: \U0001F4CD Flutter Frame Consumption\n  BQ-->>SF:\
  \ Buffer Ready\n  VS->>SF: \U0001F514 VSync-sf 触发\n  activate SF\n  SF->>SF: latchBuffer (独立 Layer)\n  SF->>SF: HWC Composite\n\
  \  deactivate SF\n\n  Note over IO: IO 线程负责图片解码、资源加载\n  Note over VA,SF: ✨ Impeller 预编译 Shader，无首帧卡顿\n"
thread_roles:
- thread: ui / main / 1.ui
  role: Dart UI 线程
  description: 执行 Dart 代码，Build/Layout/Paint，生成 Layer Tree；线程名依版本变化
  trace_tags: Engine::BeginFrame 等常见提示信号，不保证稳定
- thread: raster / 1.raster
  role: Impeller 光栅化
  description: 使用 Impeller 光栅化 Layer Tree，常见后端为 Vulkan
  trace_tags: Rasterizer::DrawToSurfaces, EntityPass::* 等提示信号
- thread: 1.io
  role: Flutter IO
  description: 图片解码、资源加载
  trace_tags: ImageDecoder
- thread: SurfaceFlinger
  role: 合成显示
  description: 将 Flutter Layer 与系统 UI 合成
key_slices:
- name: Engine::BeginFrame (hint)
  thread: ui / main / 1.ui
  description: 帧开始提示信号，线程名与可见性依版本变化
- name: EntityPass::* (hint)
  thread: raster / 1.raster
  description: Impeller 渲染提示信号，不应作为唯一判据
- name: Rasterizer::DrawToSurfaces
  thread: raster / 1.raster
  description: 常见的光栅化输出提示信号
```

## Analysis guidance

```yaml
common_issues:
- id: dart_gc
  name: Dart GC 暂停
  description: Dart 垃圾回收导致 UI 线程暂停
  detection_skill: gc_analysis
- id: raster_slow
  name: 光栅化慢
  description: Layer Tree 过于复杂，光栅化耗时
  detection_skill: gpu_analysis
- id: ui_thread_overrun
  name: 1.ui 线程超 budget
  description: 'Dart build/layout/paint 过重（ListView 大量 widget、RepaintBoundary 设置错误、

    StatelessWidget 内部不该用 Container.padding+Container.color 组合等）。

    UI 线程超 budget → Layer Tree 提交晚 → raster 线程晚开始。

    '
  detection_skill: app_frame_production
- id: raster_thread_overrun
  name: 1.raster 线程超 budget
  description: 'GPU submission 重 / fence 等待 / Impeller pipeline 创建（首次新 effect）。

    raster 线程超 budget 即使 ui 线程及时也会 jank。

    '
  detection_skill: gpu_render_in_range
- id: dual_thread_attribution_required
  name: 归因必须区分 ui/raster 双线程
  description: 'Flutter 双线程任一超 budget 都是 jank，不能只看 raster。

    归因要分别看 1.ui 上 Animator::BeginFrame 与 1.raster 上 Rasterizer::DoDraw 的时长。

    '
  detection_skill: app_frame_production
- id: platformview_strategy_unknown
  name: PlatformView 策略未确认
  description: 'PlatformView 4 种策略（VD/HC/TLHC/HCPP）默认选择随 Flutter 版本变化。

    含 PlatformView 时需先确认实际策略，否则归因会错。

    '
  detection_skill: sf_layer_count_in_range
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
  reason: Impeller 光栅化 (传输)
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
