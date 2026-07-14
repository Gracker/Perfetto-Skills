GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/webview_surface_control.skill.yaml
Source SHA-256: d6310e6c9cf9ce4049d65ba6c4b213cb0a4c401ca99c1ad81b069a6686cc1ef8
Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49
# WebView Surface Control

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_webview_surface_control
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: WEBVIEW_SURFACE_CONTROL
display_name: WebView Surface Control
description: 现代 WebView + Viz/OOP-R，独立合成
icon: web
family: webview
doc_path: rendering_pipelines/S09_webview_type.md
s_article_ref: S09
four_features:
  producer_threads:
  - VizCompositorThread
  - CrRendererMain
  - Compositor
  - CompositorTileWorker*
  expected_layer_count: N (overlay candidates)
  bufferqueue_path: CHROMIUM_TO_ASURFACECONTROL_TRANSACTION
  extra_rhythm_sources:
  - chromium_compositor_rhythm
deviation_anchors: independent_overlay_anchor_6_at_chromium_to_sf
subvariants_note: 文章 S09 列 5 种 WebView 路径中的 SurfaceControl 模式（参 webview_gl_functor 注释）。
hwc_constraint: 'overlay candidate 数量过多时 HWC plane 不够 → 部分 candidate 回退到 client composition

  → SF GPU 合成成本上升。这是 SurfaceControl 模式相对 Functor 的额外风险点。

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_viz_compositor
  thread_pattern: VizCompositorThread*
  weight: 55
- signal: has_cr_renderer
  thread_pattern: CrRendererMain*
  weight: 12
- signal: has_surface_control
  slice_pattern: '*SurfaceControl*'
  weight: 15
exclude_if:
- thread: 1.ui
```

## Teaching model

```yaml
source: rendering_pipelines/S09_webview_type.md
```

## Analysis guidance

```yaml
common_issues:
- id: viz_latency
  name: Viz 延迟
  description: Viz 合成器处理延迟
  detection_skill: sf_frame_consumption
- id: hwc_overlay_count_overflow_to_client_composition
  name: Overlay candidate 数量过多触发 HWC client composition 回退
  description: 'Chromium 为每个 overlay candidate 创建 SurfaceControl，HWC plane 数量有限。

    多 overlay 同屏时部分会被打回 client composition，GPU 带宽吃紧。

    '
  detection_skill: sf_layer_count_in_range
- id: surfacecontrol_transaction_late_apply
  name: ASurfaceTransaction apply 晚到
  description: 'Chromium 的 overlay transaction 与宿主窗口 transaction 不同帧 apply 时，用户看到 layer 错位。

    SurfaceSyncGroup（API 34+）可以让多 transaction 同帧生效。

    '
  detection_skill: sf_composition_in_range
- id: chromium_renderer_blocking_compositor
  name: Chromium Renderer 阻塞 Compositor
  description: 'CrRendererMain 卡或 commit 慢，VizCompositorThread 收不到 CompositorFrame，

    ASurfaceTransaction 提交也会延迟。

    '
  detection_skill: cpu_analysis
recommended_skills:
- sf_frame_consumption
- sf_layer_count_in_range
- cpu_analysis
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (WebView 开始生产帧)
- pattern: ^main(\s+\d+)?$
  match_by: name
  priority: 2
  reason: WebView 宿主 UI (生产)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的宿主主线程
- pattern: CrRendererMain
  match_by: name
  priority: 3
  reason: Chromium 渲染 (生产/传输)
  smart_filter:
    enabled: true
    description: 仅 Pin 属于当前 app 的 Chromium 渲染进程
- pattern: VizCompositorThread|VizCompositor
  match_by: name
  priority: 4
  reason: Viz 合成器 (传输)
  smart_filter:
    enabled: true
    description: 仅 Pin 属于当前 app 的 Viz 合成器线程/进程
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
