GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/android_view_mixed.skill.yaml
Source SHA-256: d086d880afa0f8af639222dea376588748a774b0f4d04ea54f8eabef390362ab
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# Android View 混合渲染

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_android_view_mixed
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: ANDROID_VIEW_MIXED
display_name: Android View 混合渲染
description: View + SurfaceView 混合渲染，常见于视频播放器、内嵌游戏
icon: layers
family: hwui
doc_path: rendering_pipelines/android_view_mixed.md
s_article_ref: S05
four_features:
  producer_threads:
  - main
  - RenderThread
  optional_producer_threads:
  - GLThread
  - MediaCodec*
  - '*Decoder*'
  - EGLThread
  expected_layer_count: 2
  bufferqueue_path: BBQ_TRANSACTION_INPROC + INDEPENDENT_LAYER
  extra_rhythm_sources:
  - video_codec_pacing
  - camera_request_activity
deviation_anchors: multi_path_anchor_4_5_6_8
subvariants_note: '文章 S05 区分 3 个子变种：

  - MIXED_RENDERING_HWUI_SURFACEVIEW（独立 layer 进 SF，SF 看到 ≥2 个 layer）

  - MIXED_RENDERING_HWUI_TEXTUREVIEW（外部内容回宿主 RT 通过 updateTexImage 吸收，仍单 layer）

  - MIXED_RENDERING_HYBRID（两者都有）

  Phase E 会拆分独立 ID。

  关键判别：在 SF 进程下查 layer 数量（>1 → SurfaceView，=1 → TextureView/纯宿主）。

  '
```

## Detection

```yaml
required_signals:
- thread: RenderThread
  min_count: 1
- thread: main
  min_count: 1
scoring_signals:
- signal: has_surfaceview
  slice_pattern: '*SurfaceView*'
  weight: 50
- signal: has_draw_frame
  slice_pattern: DrawFrame*
  weight: 20
- signal: has_mediacodec_thread
  thread_pattern: '*MediaCodec*'
  weight: 12
- signal: has_decoder_thread
  thread_pattern: '*Decoder*'
  weight: 8
- signal: has_update_tex_image_active
  slice_pattern: '*updateTexImage*'
  weight: 8
  min_count: 2
exclude_if:
- thread: 1.ui
- thread: CrRendererMain
- thread: UnityMain
```

## Teaching model

```yaml
title: Android View 混合渲染管线
summary: '同时使用 View 系统和 SurfaceView 进行渲染。View 部分通过 RenderThread，

  SurfaceView 有独立的渲染线程 (GLThread/MediaCodec)。常见于视频播放器、

  内嵌游戏等需要混合原生 UI 和自定义渲染的场景。

  两条链路通常比纯 View 更解耦，但窗口几何和内容同步仍需以实际 trace 判断。

  '
mermaid: "sequenceDiagram\n  participant VA as VSync-app\n  participant Main as App (main)\n  participant RT as RenderThread\n\
  \  participant GL as GLThread (SurfaceView)\n  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant\
  \ SF as SurfaceFlinger\n\n  Note over VA,SF: \U0001F4CD View + SurfaceView 混合渲染\n  VA->>Main: \U0001F514 VSync-app\n  activate\
  \ Main\n  Main->>RT: syncFrameState (View 部分)\n  deactivate Main\n\n  par View 渲染链路\n    activate RT\n    RT->>RT: DrawFrame\
  \ (HWUI)\n    RT->>BQ: queueBuffer (Layer 1)\n    deactivate RT\n  and SurfaceView 渲染链路\n    activate GL\n    GL->>GL: OpenGL/Vulkan\
  \ 渲染\n    GL->>BQ: eglSwapBuffers (Layer 2)\n    deactivate GL\n  end\n\n  VS->>SF: \U0001F514 VSync-sf\n  activate SF\n\
  \  SF->>SF: latchBuffer (多 Layer)\n  SF->>SF: HWC 合成\n  deactivate SF\n\n  Note over VA,SF: ⚠️ 两条独立链路，需注意同步问题；BLAST 只会降低竞态，不保证逐帧完美同显\n"
thread_roles:
- thread: main
  role: UI 协调
  description: 协调 View 和 SurfaceView，处理布局
- thread: RenderThread
  role: View 层渲染
  description: 渲染原生 View UI
- thread: GLThread
  role: SurfaceView 渲染
  description: 独立渲染 SurfaceView 内容
- thread: MediaCodec
  role: 视频解码
  description: 解码视频帧到 SurfaceView
key_slices:
- name: SurfaceView
  thread: any
  description: SurfaceView 相关操作
- name: Choreographer#doFrame
  thread: main
  description: 帧回调入口，协调 View 与 SurfaceView 的布局/动画
- name: syncFrameState
  thread: RenderThread
  description: 主线程与 RenderThread 同步 DisplayList/RenderNode（仅描述 View 子链路）
- name: DrawFrame
  thread: RenderThread
  description: View 层渲染
- name: eglSwapBuffers
  thread: GLThread
  description: SurfaceView 渲染线程提交帧
```

## Analysis guidance

```yaml
common_issues:
- id: layer_sync
  name: Layer 同步问题
  description: View 和 SurfaceView 帧率不同步
  detection_skill: sf_frame_consumption
- id: new_old_buffer_mismatch
  name: 新旧 buffer 混合（同帧不同步）
  description: 'SF 本轮 latch 时主窗口用新 buffer 但 SurfaceView 用旧（或反之），用户看到"新旧混合"。

    例：外层 UI 已是新状态了，视频还是旧帧；视频已经到了，遮罩还是旧位置。

    S05 §"SF 会对没有新 buffer 的 Layer 沿用旧内容"。

    '
  detection_skill: sf_frame_consumption
- id: texture_resample_overhead
  name: TextureView 采样开销
  description: 'TextureView 路径下宿主 RenderThread 通过 updateTexImage acquire 外部内容，

    再做 GPU 重采样进宿主 buffer。这一步吃宿主 RT 预算 + GPU 带宽。

    若外部内容是 YUV 还需 YUV→RGB 色彩转换，额外开销固定存在（不算 jank）。

    '
  detection_skill: render_thread_slices
- id: geometry_transaction_desync
  name: 几何 transaction 与 buffer 更新不同帧生效
  description: 'SurfaceView 的几何变化 transaction 与宿主 ViewRoot hole-punch 没在同一帧生效，

    引发位置错位一帧。可通过 SurfaceSyncGroup（API 34+）/ TransactionCommittedListener 缓解。

    S05 §"系统提供的多 Surface 同步机制"。

    '
  detection_skill: sf_composition_in_range
- id: hwc_overlay_fallback_more_layers
  name: 多 layer 触发 HWC 降级
  description: '多 layer 场景下 HWC overlay plane 数量上限被超出 / 透明混合 / 旋转缩放约束，

    导致更多 layer 被打回 client composition，GPU 合成带宽和功耗上升。

    S05 §"HWC 面对的是更复杂的 layer 组合题"。

    '
  detection_skill: sf_layer_count_in_range
- id: acquire_fence_late_blocks_layer
  name: 某条独立 layer acquire fence 晚 signal
  description: '某条独立 layer 的 acquire fence 晚 signal，SF 这一轮选择沿用该 layer 旧内容。

    典型如 MediaCodec 输出 buffer 的 GPU 写入晚于本轮 vsync-sf。

    '
  detection_skill: present_fence_timing
recommended_skills:
- scrolling_analysis
- sf_frame_consumption
- gpu_analysis
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
- pattern: ^RenderThread(\s+\d+)?$
  match_by: name
  priority: 3
  reason: App 渲染线程 (RenderThread)
  expand: true
  smart_filter:
    enabled: true
    detection_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as frame_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB 'DrawFrame*'\n  AND p.name IS NOT NULL\n  AND p.name NOT LIKE 'com.android.systemui%'\n  AND p.name\
      \ NOT LIKE 'system_server%'\n  AND p.name NOT LIKE '/system/%'\nGROUP BY p.upid\nHAVING frame_count > 5\nORDER BY frame_count\
      \ DESC\nLIMIT 10\n"
    fallback_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as frame_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB 'DrawFrame*'\n  AND p.name IS NOT NULL\nGROUP BY p.upid\nHAVING frame_count > 5\n"
- pattern: GLThread
  match_by: name
  priority: 3.5
  reason: SurfaceView 渲染
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 SurfaceView 渲染线程
- pattern: MediaCodec
  match_by: name
  priority: 4
  reason: 视频解码
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
