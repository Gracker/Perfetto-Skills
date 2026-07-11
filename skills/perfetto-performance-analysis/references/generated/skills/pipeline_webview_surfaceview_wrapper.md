GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/webview_surfaceview_wrapper.skill.yaml
Source SHA-256: b6c6297680f128ed569cfc323431a2314384977ebb08c08e6c50bd0f2387acfc
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# WebView SurfaceView Wrapper

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_webview_surfaceview_wrapper
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: WEBVIEW_SURFACEVIEW_WRAPPER
display_name: WebView SurfaceView Wrapper
description: WebView 全屏视频包装模式
icon: video
family: webview
doc_path: rendering_pipelines/webview_surfaceview_wrapper.md
s_article_ref: S09
four_features:
  producer_threads:
  - MediaCodec*
  - media.codec
  - media.swcodec
  - CrRendererMain
  expected_layer_count: 1
  bufferqueue_path: MEDIACODEC_TO_INDEPENDENT_SURFACE
  extra_rhythm_sources:
  - video_codec_pacing
deviation_anchors: video_independent_surface_anchor_4_5_6_at_codec
related_pipeline: 全屏视频部分等价于 VIDEO_OVERLAY_HWC（S12），与之配合使用
subvariants_note: 文章 S09 列出的 5 种 WebView 路径之一（参 webview_gl_functor 注释）。
```

## Detection

```yaml
scoring_signals:
- signal: has_webview
  slice_pattern: '*WebView*'
  weight: 30
- signal: has_webview_core
  thread_pattern: WebViewCore*
  weight: 10
- signal: has_cr_renderer
  thread_pattern: CrRendererMain*
  weight: 10
- signal: has_surfaceview
  slice_pattern: '*SurfaceView*'
  weight: 25
- signal: has_video
  slice_pattern: '*Video*'
  weight: 12
- signal: has_mediacodec
  slice_pattern: '*MediaCodec*'
  weight: 13
exclude_if:
- thread: 1.ui
```

## Teaching model

```yaml
title: WebView SurfaceView Wrapper 渲染管线
summary: 'WebView 全屏视频播放模式，使用 SurfaceView 包装视频内容。

  视频解码通过 MediaCodec，直接输出到 SurfaceView。

  常见于网页视频全屏播放场景。

  '
mermaid: "sequenceDiagram\n  participant Main as App (main)\n  participant WV as WebView\n  participant CR as CrRendererMain\n\
  \  participant SV as SurfaceView\n  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\
  \n  Note over Main,SF: \U0001F4CD WebView SurfaceView Wrapper (全屏视频)\n  Main->>WV: 加载视频页面\n  WV->>CR: 请求视频渲染\n\n  activate\
  \ CR\n  CR->>SV: 创建 SurfaceView 包装\n  CR->>BQ: 视频解码输出\n  deactivate CR\n\n  Note over SV,SF: 视频帧独立路径\n  BQ-->>SF: 视频 Buffer\
  \ Ready\n  VS->>SF: \U0001F514 VSync-sf\n  activate SF\n  SF->>SF: latchBuffer (视频 Layer)\n  SF->>SF: HWC Overlay/Composite\n\
  \  deactivate SF\n\n  Note over Main,SF: \U0001F3AC 全屏视频使用独立 Surface 优化\n"
thread_roles:
- thread: main
  role: App 控制
  description: 控制 WebView 和播放状态
- thread: CrRendererMain
  role: Chromium 渲染
  description: WebView 内容和视频协调
- thread: MediaCodec
  role: 视频解码
  description: 硬件视频解码
- thread: SurfaceFlinger
  role: 合成/Overlay
  description: 将视频 SurfaceView Layer 以 Overlay 或 GPU 合成方式输出
key_slices:
- name: MediaCodec
  thread: any
  description: 视频解码（queue/dequeue/releaseOutputBuffer 等）
- name: SurfaceView
  thread: any
  description: 全屏视频 SurfaceView 创建/attach/resize
- name: latchBuffer
  thread: SurfaceFlinger
  description: SurfaceFlinger 获取视频 Buffer（决定 Overlay/合成）
- name: HWC
  thread: any
  description: 硬件合成/Overlay 相关调用（不同厂商 trace 名称可能不同）
```

## Analysis guidance

```yaml
common_issues:
- id: codec_underflow
  name: MediaCodec output buffer 不足
  description: 'MediaCodec releaseOutputBuffer 频率与显示节奏不匹配——pool 用完时下一次 dequeueOutputBuffer 阻塞。

    触发原因：HWC 消费慢 / SurfaceView consumer back-pressure / decoder 解码慢。

    '
  detection_skill: gpu_render_in_range
- id: hwc_overlay_decision_for_video
  name: HWC overlay 决策对视频敏感
  description: '视频 buffer 通常 YUV NV12/P010 格式，HWC 倾向 device composition；但 DRM/HDCP 受保护内容必须走 secure overlay；

    旋转、缩放比例超 HWC scaler 能力或 HDR 元数据不支持 → 回退 client composition 增加 GPU 负担。

    '
  detection_skill: sf_layer_count_in_range
- id: webview_video_chrome_decoupling
  name: 网页视频与外壳 UI 解耦
  description: '视频 layer 走 MediaCodec → 独立 Surface 路径，CrRendererMain 仅管理外壳。

    若网页外壳 UI（控制条、字幕）渲染卡，但视频流畅，要分别归因。

    '
  detection_skill: sf_frame_consumption
recommended_skills:
- sf_frame_consumption
- cpu_analysis
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (WebView/视频开始生产帧)
- pattern: ^main(\s+\d+)?$
  match_by: name
  priority: 2
  reason: App 控制 (生产)
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
- pattern: MediaCodec
  match_by: name
  priority: 4
  reason: 视频解码 (生产/传输)
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
