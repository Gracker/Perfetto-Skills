GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/flutter_textureview.skill.yaml
Source SHA-256: 2d03797b34f4861a16e2fdbae1635978d0d1d773eb13c59bf4ea9db059e331a2
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# Flutter TextureView

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_flutter_textureview
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: FLUTTER_TEXTUREVIEW
display_name: Flutter TextureView
description: Flutter TextureView render mode，宿主侧纹理合成路径
icon: flutter
family: flutter
doc_path: rendering_pipelines/S10_flutter_type.md
s_article_ref: S10
four_features:
  producer_threads:
  - 1.ui
  - 1.raster
  consumer_threads:
  - RenderThread
  expected_layer_count: 1
  bufferqueue_path: ENGINE_TO_SURFACETEXTURE_TO_HOST_BBQ
  extra_rhythm_sources:
  - engine_animator_beginframe
  - external_producer_onFrameAvailable
deviation_anchors: engine_to_host_resample_anchor_4_5_6_at_engine_then_host_resample
why_not_surfaceview: 'Flutter 选择 TextureView 模式的常见原因：

  - 透明背景（SurfaceView 无法透明混合）

  - 与原生 View 任意 transform 混合

  - PlatformView 嵌入需要

  '
cost_vs_surfaceview: '相比 SurfaceView 模式有额外开销：

  - 宿主 RT updateTexImage acquire + GPU 重采样

  - YUV→RGB 色彩转换（如适用）

  - 宿主 buffer 与 Flutter buffer 同步等待

  可能多一帧延迟（与 S04 一致）。

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_surface_texture
  slice_pattern: '*SurfaceTexture*'
  weight: 30
- signal: has_update_tex_image
  slice_pattern: '*updateTexImage*'
  weight: 15
- signal: has_host_render_thread
  thread_pattern: RenderThread*
  weight: 12
- signal: has_flutter_raster
  thread_pattern: '*raster*'
  weight: 10
```

## Teaching model

```yaml
source: rendering_pipelines/S10_flutter_type.md
```

## Analysis guidance

```yaml
common_issues:
- id: platformview_overhead
  name: TextureView / host composition 开销
  description: 宿主侧纹理采样与合成的额外开销
  detection_skill: render_thread_slices
- id: dual_pipeline_jank_attribution
  name: 双管线 jank 归因（Flutter ui+raster + 宿主 RT）
  description: 'Flutter TextureView 模式下 jank 可能来自三处：1.ui / 1.raster / 宿主 RenderThread。

    S04 §"为什么问题最终都暴露在宿主"——宿主 RT 是最终收口者，但源头可能在 Engine 任一线程或 onFrameAvailable 回调链延迟。

    '
  detection_skill: render_thread_slices
- id: host_resample_overhead
  name: 宿主 RT updateTexImage + GPU 重采样开销
  description: '宿主 RT 在 syncFrameState 阶段做 updateTexImage acquire（DeferredLayerUpdater::apply()），再 GPU 重采样进宿主 buffer。

    这一步是 TextureView 模式相比 SurfaceView 模式的主要额外成本。

    '
  detection_skill: gpu_render_in_range
- id: onframeavailable_to_invalidate_late
  name: onFrameAvailable → invalidate → 下一次 vsync-app 链路晚
  description: 'Engine queueBuffer 后通过 BufferQueue → onFrameAvailable → SurfaceTexture listener →

    TextureView.updateLayer → invalidate → ViewRootImpl.scheduleTraversals → 下一次 vsync-app。

    这条链路任一段晚，宿主下一帧就不会消费最新内容。S04 §"外部内容到达会反向驱动宿主窗口申请新的一帧"。

    '
  detection_skill: app_frame_production
- id: dual_fence_layers
  name: TextureView 实际有两套 fence
  description: 'Engine 侧 fence 保护"宿主 updateTexImage 不读到 GPU 没写完的 Flutter 内容"；

    宿主侧 fence 保护"SF latch 不读到宿主 GPU 没合成完的最终窗口结果"。两层不能混淆。

    '
  detection_skill: present_fence_timing
recommended_skills:
- scrolling_analysis
- render_thread_slices
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
  reason: Flutter 光栅化 (传输)
- pattern: SurfaceTexture|updateTexImage|onFrameAvailable
  match_by: name
  priority: 3.5
  reason: SurfaceTexture (TextureView 出图关键提示)
- pattern: ^RenderThread(\s+\d+)?$
  match_by: name
  priority: 4
  reason: Android 合成 (传输)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 RenderThread（多 app trace 下减少噪音）
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
