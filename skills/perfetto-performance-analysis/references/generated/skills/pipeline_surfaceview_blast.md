GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/surfaceview_blast.skill.yaml
Source SHA-256: 6f75d6b4ac8b5c26e7e59c18854de7a773a30341f10dfa2763c4bf5673139bb6
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# SurfaceView (BLAST)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_surfaceview_blast
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: SURFACEVIEW_BLAST
display_name: SurfaceView (BLAST)
description: 独立 SurfaceView + BLAST 同步，用于自定义 GL 渲染、媒体播放
icon: surface
family: surface
doc_path: rendering_pipelines/surfaceview.md
s_article_ref: S03
four_features:
  producer_threads:
  - GLThread
  optional_producer_threads:
  - media.codec*
  - media.swcodec
  - cameraserver
  - '*Decoder*'
  - EGLThread
  expected_layer_count: 2
  bufferqueue_path: BBQ_TRANSACTION_INPROC + INDEPENDENT_LAYER
  extra_rhythm_sources:
  - video_codec_pacing
  - camera_request_activity
  - game_engine_loop
deviation_anchors: independent_anchor_4_5_6_join_at_8
sublayer_constants:
  default: -2 (APPLICATION_MEDIA_SUBLAYER, 之下，依赖 hole-punch 透出)
  setZOrderMediaOverlay: -1 (APPLICATION_MEDIA_OVERLAY_SUBLAYER, 仍之下但在其他默认 SV 之上，多 SV 叠层用)
  setZOrderOnTop: 1 (APPLICATION_PANEL_SUBLAYER, 之上，宿主任何 UI 都会被遮)
layer_signature: SurfaceView[<package>/<activity>]#<id> 或 SurfaceView - <package>/<activity>#<id>
subvariants_note: '文章 S03 描述 SurfaceView 4 个版本里程碑：

  - Android N 之前：跨进程独立 BufferQueue，几何与宿主不同步（错位一帧经典症状）

  - Android N: 引入 position sync / deferTransactionUntil

  - Android Q: 现代 SurfaceControl + parent-child 层级

  - Android S/12+: BLAST / BLASTBufferQueue 统一 buffer 与 transaction

  当前 ID 主要覆盖 Android 12+/BLAST 路径。Phase E 会拆 SURFACEVIEW_LEGACY (跨进程 BufferQueue) 独立 ID。

  '
known_limitations: '- SurfaceView 内容不在宿主 HWUI 绘制树里，任意 View transform 与周围 View 混合无法直接做（需改 TextureView 或用 SurfaceControl 几何变换近似）

  - Android 14/U 之前 0-1 半透明支持有限，Z-below 时受 hole-punch 逻辑影响

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_surfaceview
  slice_pattern: '*SurfaceView*'
  min_count: 10
  weight: 55
- signal: has_blast
  slice_pattern: '*BLASTBufferQueue*'
  weight: 20
- signal: has_gl_thread
  thread_pattern: '*GLThread*'
  weight: 12
- signal: has_glsurface_thread
  thread_pattern: '*GLSurface*'
  weight: 8
exclude_if:
- thread: 1.ui
- thread: CrRendererMain
- thread: UnityMain
- thread: UnityGfx
```

## Teaching model

```yaml
title: SurfaceView (BLAST) 渲染管线
summary: '使用独立的 Surface 进行渲染，常见于 OpenGL 游戏、视频播放器。

  SurfaceView 有自己的 Layer，不受 View 系统约束，可以在独立线程渲染。

  现代 Android 上常通过 BLAST / Transaction 模型协同 Buffer 与几何更新，但具体内部 trace 细节依版本而异。

  '
mermaid: "sequenceDiagram\n  participant App as App Thread\n  participant GL as GLThread\n  participant BQ as BufferQueue\n\
  \  participant TX as BufferTX\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\n  Note over App,SF: \U0001F4CD\
  \ SurfaceView (BLAST) 独立渲染\n  App->>GL: 请求绘制\n  activate GL\n  GL->>BQ: dequeueBuffer\n  GL->>GL: OpenGL/Vulkan 渲染\n  GL->>GL:\
  \ GPU 绘制命令\n  GL->>BQ: queueBuffer + Transaction\n  deactivate GL\n\n  BQ-->>TX: BLAST Transaction\n  VS->>SF: \U0001F514\
  \ VSync-sf\n  activate SF\n  TX->>SF: setTransactionState\n  SF->>SF: latchBuffer\n  SF->>SF: HWC 合成 (独立 Layer)\n  deactivate\
  \ SF\n\n  Note over App,SF: ✨ 独立于 App UI；但同步与合成效果仍取决于窗口变换、HWC 与系统负载\n"
thread_roles:
- thread: GLThread
  role: 独立渲染线程
  description: OpenGL/Vulkan 渲染，直接提交到 SurfaceView
- thread: SurfaceFlinger
  role: 独立层合成
  description: SurfaceView 作为独立 Layer 合成
key_slices:
- name: eglSwapBuffers
  thread: GLThread
  description: 交换 Buffer
- name: dequeueBuffer
  thread: any
  description: 获取可写 Buffer（可能阻塞在 BufferQueue）
- name: queueBuffer
  thread: any
  description: 提交 Buffer（现代系统中常与 Transaction 路径协同）
- name: SurfaceView
  thread: any
  description: SurfaceView 操作
```

## Analysis guidance

```yaml
common_issues:
- id: geometry_desync_with_host
  name: 几何 transaction 与宿主 ViewRoot 不同帧生效
  description: 'SurfaceView 几何（位置/大小/裁剪）属于 child SurfaceControl，宿主 hole-punch 与周边 UI 在 ViewRoot/HWUI 一侧。

    几何 transaction 与宿主 ViewRoot 提交不同帧时出现错位（"宿主到了新位置，SurfaceView 仍按旧几何合成"）。

    BLAST 路径下相关 transaction 可 merge 到目标帧，但需要正确使用 sync transaction。S03 §"几何更新与宿主窗口需要同帧生效"。

    '
  detection_skill: sf_composition_in_range
- id: producer_in_wrong_process_traced
  name: 独立 Producer 在错的进程里被忽略
  description: 'SurfaceView 的独立 Producer 可能在跨进程：cameraserver / media.codec / media.swcodec / Codec2 vendor service 等。

    Trace 时只盯主 App 进程会漏看真正的 buffer 生产瓶颈。S03 §"独立内容侧通常有自己的起帧方式"。

    '
  detection_skill: gpu_render_in_range
- id: hwc_overlay_fallback_constraints
  name: HWC overlay 决策回退
  description: '独立 layer 给系统 device composition 的机会，但条件不满足时回退 client：

    - buffer 格式（YUV NV12/P010 vs RGBA）

    - DRM/HDCP 受保护内容（需 secure overlay）

    - overlay plane 数量上限

    - 缩放比例与旋转超 HWC scaler 能力

    - 色彩空间与 HDR 元数据

    S03 §"HWC 的 overlay 决策对这类场景更敏感"。

    '
  detection_skill: sf_layer_count_in_range
- id: hole_punch_late_with_z_below
  name: Z-below 模式下 hole-punch 与几何动画错位
  description: '默认 Z-below 模式（sublayer=-2）时 SurfaceView 依赖宿主 hole-punch 透出，

    宿主 ViewRoot draw/punchHole 与几何 transaction 没同帧生效会让用户看到一帧不协调。

    Android 14/U 之前半透明 alpha 支持有限。

    '
  detection_skill: sf_composition_in_range
- id: dequeue_buffer_blocked_by_release_fence
  name: 独立 Producer dequeueBuffer 卡 release fence
  description: '独立 Producer 的 dequeueBuffer 长时间等待，因为 HWC 还没释放上一帧 buffer

    （release fence 晚回，由 HWC presentDisplay → getReleaseFences → SF/BufferQueue → Producer 回传）。

    '
  detection_skill: render_thread_slices
recommended_skills:
- gpu_analysis
- sf_frame_consumption
- sf_layer_count_in_range
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (App 开始生产帧)
- pattern: GLThread
  match_by: name
  priority: 2
  reason: 独立渲染线程
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 GLThread（避免 pin 到系统/其他应用的 GLThread）
- pattern: ^VSYNC-sf$
  match_by: name
  priority: 3.5
  reason: VSync (SurfaceFlinger 消费/合成)
- pattern: ^BufferTX
  match_by: name
  priority: 3.8
  reason: BufferTX (SurfaceFlinger 事务)
- pattern: ^[sS]urface[fF]linger
  match_by: name
  priority: 4
  reason: SurfaceFlinger (最终合成/显示)
  main_thread_only: true
```
