GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/textureview_standard.skill.yaml
Source SHA-256: 66e78a2be5c0db0e4831882e1deebb21e846d67d15400ccfe9a17c35ab503f81
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# TextureView 标准

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_textureview_standard
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: TEXTUREVIEW_STANDARD
display_name: TextureView 标准
description: SurfaceTexture 纹理采样/合成模式，与 View 层次集成
icon: texture
family: surface
doc_path: rendering_pipelines/textureview.md
s_article_ref: S04
four_features:
  producer_threads:
  - RenderThread
  optional_external_producer_threads:
  - media.codec*
  - media.swcodec
  - cameraserver
  - engine threads
  expected_layer_count: 1
  bufferqueue_path: HOST_RESAMPLE
  extra_rhythm_sources:
  - external_producer_onFrameAvailable
deviation_anchors: host_resample_anchor_4_5_anchor_5_anchor_6
hard_constraint: '强制依赖 hardwareAccelerated=true（HWUI Hardware/Texture Layer）。

  宿主 Window 没开硬件加速时 TextureView 不工作——这是它和 SurfaceView 的架构区别之一。

  '
known_limitation: '无法显示 DRM 受保护内容——HWUI 通用渲染 context 不在 protected 模式下，读 secure buffer 只能拿到黑屏。

  需 DRM 视频时必须改用 SurfaceView。

  '
consumer_strategy_note: '现代 HWUI 路径通过 ASurfaceTexture_dequeueBuffer 取最新 pending buffer，丢弃中间帧。

  Producer 比宿主消费快时 trace 上预期 dropped/skipped frames，不是逐帧消费。

  若业务需要逐帧消费（视频编辑/分析）应改用 ImageReader 自管 BufferQueue。

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_surface_texture
  slice_pattern: '*SurfaceTexture*'
  min_count: 5
  weight: 25
- signal: has_update_tex_image
  slice_pattern: '*updateTexImage*'
  min_count: 1
  weight: 15
- signal: has_on_frame_available
  slice_pattern: '*onFrameAvailable*'
  weight: 8
- signal: has_render_thread
  thread_pattern: RenderThread*
  weight: 20
- signal: has_deferred_layer_updater
  slice_pattern: '*DeferredLayerUpdater*'
  weight: 8
exclude_if:
- thread: 1.ui
- thread: 1.raster
- thread: CrRendererMain
- slice_pattern: '*TBS*'
- slice_pattern: '*X5*'
- slice_pattern: '*UCCore*'
```

## Teaching model

```yaml
title: TextureView 渲染管线
summary: '使用 SurfaceTexture 将渲染内容作为纹理集成到 View 层次中。

  支持 View 的所有变换（缩放、裁剪、透明度），但会增加纹理采样/合成带宽开销。

  适合需要与 View 混合显示的场景。`updateTexImage` / `onFrameAvailable` 常见但不是稳定 contract。

  '
mermaid: "sequenceDiagram\n  participant VA as VSync-app\n  participant Main as App (main)\n  participant RT as RenderThread\n\
  \  participant Producer as Producer Thread\n  participant ST as SurfaceTexture\n  participant BQ as BufferQueue\n  participant\
  \ VS as VSync-sf\n  participant SF as SurfaceFlinger\n\n  Note over VA,SF: \U0001F4CD TextureView 渲染链路\n  Producer->>ST:\
  \ 渲染内容到 SurfaceTexture\n  Producer->>ST: queueBuffer\n  ST-->>RT: onFrameAvailable / listener callback\n\n  VA->>Main: \U0001F514\
  \ VSync-app\n  activate Main\n  Main->>RT: syncFrameState\n  deactivate Main\n\n  activate RT\n  RT->>RT: DrawFrame\n  RT->>RT:\
  \ 绑定 SurfaceTexture 纹理\n  RT->>RT: 绘制到 View 层级\n  RT->>BQ: queueBuffer\n  deactivate RT\n\n  VS->>SF: \U0001F514 VSync-sf\n\
  \  activate SF\n  SF->>SF: latchBuffer\n  SF->>SF: HWC 合成\n  deactivate SF\n\n  Note over VA,SF: ⚠️ 需要 GPU 采样 → 开销高于 SurfaceView\n"
thread_roles:
- thread: main
  role: UI 集成
  description: 管理 TextureView 在 View 层次中的位置
- thread: RenderThread
  role: 纹理上传 + 合成
  description: 将 SurfaceTexture 内容作为纹理绘制
key_slices:
- name: updateTexImage (hint)
  thread: RenderThread
  description: 常见的纹理消费信号；名称可见性依版本而异
- name: SurfaceTexture
  thread: any
  description: SurfaceTexture 操作
- name: onFrameAvailable
  thread: any
  description: 生产者有新帧可用，触发消费者侧更新纹理
- name: syncFrameState
  thread: RenderThread
  description: 宿主 UI 与 RenderThread 同步，驱动 TextureView 合成
- name: DrawFrame
  thread: RenderThread
  description: RenderThread 绑定纹理并绘制到 View 层级
```

## Analysis guidance

```yaml
common_issues:
- id: texture_upload_slow
  name: 纹理更新/采样慢
  description: 宿主侧纹理更新、采样或合成耗时过长
  detection_skill: render_thread_slices
- id: yuv_rgb_resampling_overhead
  name: GPU 重采样 + YUV→RGB 色彩转换开销
  description: '宿主 RenderThread 在执行 TextureView 所在的 DisplayList 时 GPU 要采样外部纹理进宿主窗口 buffer。

    GL 路径：samplerExternalOES（YUV→RGB 由 EGL/GL 扩展或硬件采样路径处理）。

    Vulkan 路径：AHardwareBuffer → VkImage + VkSamplerYcbcrConversion（不要写死 VK_FORMAT_*）。

    外部 buffer 尺寸常与显示尺寸不一致还要做缩放，alpha/圆角/旋转一并结算。S04 §"宿主 GPU 的重采样与 YUV→RGB 代价"。

    '
  detection_skill: gpu_render_in_range
- id: external_producer_late_arrival
  name: 外部 Producer 晚到导致宿主收口失败
  description: '外部内容晚到 SurfaceTexture，宿主下一次 doFrame 还没到，或宿主 syncFrameState 阶段没消费到最新 buffer。

    看 trace 时要往上游追外部 Producer 的 queueBuffer 和 onFrameAvailable 时刻；

    Producer 可能跨进程（media.codec/cameraserver/Codec2 vendor service）。S04 §"外部 Producer 把内容送到 SurfaceTexture"。

    '
  detection_skill: render_thread_slices
- id: frame_drop_strategy_takes_latest
  name: TextureView consumer 倾向取最新（丢中间帧）
  description: '现代 HWUI 路径通过 ASurfaceTexture_dequeueBuffer 取最新 pending buffer，丢弃中间帧。

    Producer 比宿主消费快时 trace 上预期 dropped/skipped frames。需逐帧消费（视频编辑/分析）应改 ImageReader。

    S04 §"updateTexImage() 在 syncFrameState 阶段的 acquire 时机"。

    '
  detection_skill: app_frame_production
- id: requires_hardware_acceleration
  name: TextureView 不支持 hardwareAccelerated=false
  description: 'TextureView 强制依赖 HWUI Hardware/Texture Layer 机制——宿主 Window 没开硬件加速时直接不工作。

    和 SurfaceView 不同（独立 Surface 与硬件加速无关）。

    '
  detection_skill: render_thread_slices
- id: cannot_display_drm_protected_content
  name: 无法显示 DRM 受保护内容
  description: '受保护 buffer (GRALLOC_USAGE_PROTECTED) 只能通过 secure composition / secure overlay 路径读取。

    TextureView 走宿主 GPU 重采样而 HWUI 通用 context 不在 protected 模式 → 黑屏。需要 DRM 视频时改用 SurfaceView。

    '
  detection_skill: sf_composition_in_range
- id: dual_fence_layers
  name: TextureView 实际有两套 fence
  description: '外部 Producer 侧 fence 保护"宿主 updateTexImage 时不读到 GPU 没写完的外部内容"；

    宿主侧 fence 保护"SF latch 时不读到宿主 GPU 没合成完的最终窗口结果"。两层不能混淆。

    '
  detection_skill: present_fence_timing
recommended_skills:
- render_thread_slices
- gpu_analysis
- present_fence_timing
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (App 开始生产帧)
- pattern: ^main(\s+\d+)?$
  match_by: name
  priority: 2
  reason: App 主线程 (生产帧)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 main 线程
    detection_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as frame_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB 'DrawFrame*'\n  AND p.name IS NOT NULL\n  AND p.name NOT LIKE 'com.android.systemui%'\n  AND p.name\
      \ NOT LIKE 'system_server%'\n  AND p.name NOT LIKE '/system/%'\nGROUP BY p.upid\nHAVING frame_count > 5\nORDER BY frame_count\
      \ DESC\nLIMIT 10\n"
    fallback_sql: 'SELECT DISTINCT p.name as process_name, COUNT(*) as slice_count

      FROM slice s

      JOIN thread_track tt ON s.track_id = tt.id

      JOIN thread t ON tt.utid = t.utid

      JOIN process p ON t.upid = p.upid

      WHERE t.name = ''main''

      GROUP BY p.upid

      HAVING slice_count > 10

      ORDER BY slice_count DESC

      LIMIT 10

      '
- pattern: SurfaceTexture|updateTexImage|onFrameAvailable
  match_by: name
  priority: 2.5
  reason: SurfaceTexture (纹理生产-消费/出图关键)
- pattern: ^RenderThread(\s+\d+)?$
  match_by: name
  priority: 3
  reason: App 渲染线程 (RenderThread)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 有活跃渲染的进程的 RenderThread
    detection_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as frame_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB 'DrawFrame*'\n  AND p.name IS NOT NULL\n  AND p.name NOT LIKE 'com.android.systemui%'\n  AND p.name\
      \ NOT LIKE 'system_server%'\n  AND p.name NOT LIKE '/system/%'\nGROUP BY p.upid\nHAVING frame_count > 5\nORDER BY frame_count\
      \ DESC\nLIMIT 10\n"
    fallback_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as slice_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB 'DrawFrame*'\nGROUP BY p.upid\nHAVING slice_count > 10\nORDER BY slice_count DESC\nLIMIT 10\n"
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
