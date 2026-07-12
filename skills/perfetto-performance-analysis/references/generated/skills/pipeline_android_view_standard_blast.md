GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/android_view_standard_blast.skill.yaml
Source SHA-256: 5af1d20831b0954dec49d5e02a7ebbfda46914fc92cf97a079994d09c5b5b92b
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# 标准 Android View (BLAST)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_android_view_standard_blast
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: ANDROID_VIEW_STANDARD_BLAST
display_name: 标准 Android View (BLAST)
description: Android 11+/12+ 常见的 HWUI + 现代 Transaction/BLAST 提交流程
icon: android
family: hwui
doc_path: rendering_pipelines/android_view_standard.md
s_article_ref: S02
four_features:
  producer_threads:
  - RenderThread
  expected_layer_count: 1
  bufferqueue_path: BBQ_TRANSACTION_INPROC
  extra_rhythm_sources: []
deviation_anchors: baseline_complete_1_to_12
```

## Detection

```yaml
required_signals:
- thread: RenderThread
  min_count: 1
- thread: main
  min_count: 1
scoring_signals:
- signal: has_draw_frame
  slice_pattern: DrawFrame*
  weight: 25
- signal: has_choreographer
  slice_pattern: '*Choreographer#doFrame*'
  weight: 20
- signal: has_sync_frame
  slice_pattern: '*syncFrameState*'
  weight: 15
- signal: has_queue_buffer
  slice_pattern: '*queueBuffer*'
  weight: 12
- signal: has_blast_buffer_queue_hint
  slice_pattern: '*BLASTBufferQueue*'
  weight: 10
- signal: has_set_transaction_state
  slice_pattern: '*setTransactionState*'
  weight: 10
- signal: has_apply_transaction
  slice_pattern: '*applyTransaction*'
  weight: 12
exclude_if:
- thread: 1.ui
- thread: 1.raster
- thread: CrRendererMain
- thread: UnityMain
- thread: UnityGfx
```

## Teaching model

```yaml
title: Android View 标准渲染管线 (BLAST)
summary: 'Android 11+/12+ 设备上常见的渲染管线：View 系统由 RenderThread 通过现代 Transaction/BLAST

  提交流程更新 Buffer 和窗口状态，提升原子性更新与同步性，减少撕裂/尺寸不同步等问题。

  相比传统 BufferQueue 提交流程，它通常能减少由“提交不同步/额外缓冲/等待”导致的卡顿与延迟，

  但具体收益会随设备实现与负载变化，建议以 trace 为准。


  版本要点（以 AOSP/厂商实现为准）:

  - Android 11+：引入 BLASTBufferQueue（不同设备/ROM 覆盖率不同）

  - Android 12+：BLASTBufferQueue/Transaction 提交流程更普遍（原子性更新）

  - 与 FrameTimeline 等帧诊断能力结合后，可更容易定位“生产慢/合成慢/显示慢”

  - 新版本持续在 Transaction 批处理、合成调度与帧诊断上演进，建议用 trace 验证实际链路

  '
mermaid: "sequenceDiagram\n  participant VA as VSync-app\n  participant Main as App (main)\n  participant RT as RenderThread\n\
  \  participant BQ as BufferQueue<br/>(QueuedBuffer)\n  participant VS as VSync-sf\n  participant TX as BufferTX\n  participant\
  \ SF as SurfaceFlinger\n\n  Note over VA,SF: \U0001F4CD Frame N Production Phase\n  VA->>Main: \U0001F514 VSync-app 信号触发\n\
  \  activate Main\n  Main->>Main: Choreographer#doFrame\n  Main->>Main: Input → Animation → Measure → Layout → Draw\n  Main->>RT:\
  \ syncFrameState (阻塞等待)\n  deactivate Main\n\n  activate RT\n  RT->>BQ: dequeueBuffer\n  RT->>RT: DrawFrame (执行 GPU 命令)\n\
  \  RT->>RT: Flush GPU Commands\n  RT->>BQ: queueBuffer / transaction submit\n  deactivate RT\n\n  Note over BQ,SF: \U0001F4CD\
  \ Frame N Consumption Phase\n  BQ-->>TX: Buffer Ready (BLAST Transaction)\n  VS->>SF: \U0001F514 VSync-sf 信号触发\n  activate\
  \ SF\n  TX->>SF: setTransactionState (常见)\n  SF->>SF: SF main loop / composite\n  SF->>SF: latchBuffer (获取 Buffer)\n  SF->>SF:\
  \ HWC Composite (合成)\n  SF->>SF: Present to Display\n  deactivate SF\n\n  Note over VA,SF: ⏱️ 关键耗时点：Main/RT阻塞、GPU渲染、SF合成\n"
thread_roles:
- thread: main
  role: UI 构建
  description: 处理 Input/Animation/Measure/Layout/Draw，生成 DisplayList
  trace_tags: Choreographer#doFrame, measure, layout, draw
- thread: RenderThread
  role: GPU 渲染
  description: 执行 GL/Vulkan 绘制命令，管理 GPU 资源，提交 BLAST Transaction
  trace_tags: DrawFrame, syncFrameState, queueBuffer（具体 trace 名称依版本变化）
- thread: SurfaceFlinger
  role: 合成显示
  description: 接收 Transaction，Latch Buffer，HWC 合成多个 Layer
  trace_tags: setTransactionState, latchBuffer, FrameTimeline/SF 主循环片段
key_slices:
- name: Choreographer#doFrame
  thread: main
  description: 帧回调入口，开始 UI 构建
- name: DrawFrame
  thread: RenderThread
  description: 开始 GPU 渲染流程
- name: syncFrameState
  thread: RenderThread
  description: UI 线程与 RenderThread 同步 DisplayList
- name: BLASTBufferQueue (hint)
  thread: RenderThread
  description: BLAST 适配器提示信号，可能不可见
- name: setTransactionState (hint)
  thread: SurfaceFlinger
  description: 系统侧事务处理提示信号，具体名称依版本而异
```

## Analysis guidance

```yaml
common_issues:
- id: rt_stall
  name: RenderThread 阻塞
  description: RenderThread 等待 GPU Fence 或 Buffer 时间过长
  detection_skill: render_thread_slices
- id: main_jank
  name: 主线程卡顿
  description: 主线程 Measure/Layout/Draw 耗时过长
  detection_skill: app_frame_production
- id: sync_frame_slow
  name: SyncFrameState 慢
  description: UI 线程与 RenderThread 同步耗时过长
  detection_skill: render_thread_slices
- id: buffer_slot_blocked
  name: BufferSlot 卡 ACQUIRED
  description: 'dequeueBuffer 长时间等待，根因是上一帧对应的 BufferSlot 仍卡在 ACQUIRED 状态——

    HWC 还在显示该 buffer 或 SF 这一轮没把它释放，release fence 因此晚回。

    S02 §dequeueBuffer 为什么会等：要按 release fence → acquire fence → SF latch 这条链回查。

    '
  detection_skill: render_thread_slices
- id: doframe_callback_imbalance
  name: doFrame 5-callback 不均衡
  description: 'Choreographer#doFrame 内 INPUT/ANIMATION/INSETS_ANIMATION/TRAVERSAL/COMMIT 5 个 callback 中

    某段独占预算（典型如 TRAVERSAL 因为深嵌套 ViewGroup measure 反复触发）。

    '
  detection_skill: app_frame_production
- id: hwc_client_fallback
  name: HWC 降级 client composition
  description: 'HWC 把原本 DEVICE 的 layer 在 validateDisplay→getChangedCompositionTypes 阶段降级到 CLIENT，

    SF 用 GPU 补合成。常见触发：透明、旋转、受保护内容、plane 数量不足。表现为 SF Duration 抬升 + GPU 带宽吃紧。

    '
  detection_skill: sf_composition_in_range
- id: present_fence_late
  name: present fence 持续偏晚
  description: '提交按时但 present fence 偏晚——问题已落到系统收尾阶段（panel 模式切换/刷新率切换/扫描输出延迟）。

    S02 §"为什么 HWC / present fence 要放到最后看"。

    '
  detection_skill: present_fence_timing
recommended_skills:
- scrolling_analysis
- jank_frame_detail
- render_thread_slices
- app_frame_production
- cpu_analysis
- binder_analysis
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
    description: 仅 Pin 活跃渲染进程的主线程
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
    description: 仅 Pin 有活跃渲染的进程的 RenderThread
    detection_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as frame_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB 'DrawFrame*'\n  AND p.name IS NOT NULL\n  AND p.name NOT LIKE 'com.android.systemui%'\n  AND p.name\
      \ NOT LIKE 'system_server%'\n  AND p.name NOT LIKE '/system/%'\nGROUP BY p.upid\nHAVING frame_count > 5\nORDER BY frame_count\
      \ DESC\nLIMIT 10\n"
    fallback_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as slice_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB 'DrawFrame*'\nGROUP BY p.upid\nHAVING slice_count > 10\nORDER BY slice_count DESC\nLIMIT 10\n"
- pattern: ^QueuedBuffer
  match_by: name
  priority: 4
  reason: BufferQueue/BLAST (传输)
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程相关的 BufferQueue
    detection_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as frame_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB 'DrawFrame*'\n  AND p.name IS NOT NULL\n  AND p.name NOT LIKE 'com.android.systemui%'\n  AND p.name\
      \ NOT LIKE 'system_server%'\n  AND p.name NOT LIKE '/system/%'\nGROUP BY p.upid\nHAVING frame_count > 5\nORDER BY frame_count\
      \ DESC\nLIMIT 10\n"
    fallback_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as slice_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB '*BufferQueue*'\nGROUP BY p.upid\nHAVING slice_count > 10\nORDER BY slice_count DESC\nLIMIT 10\n"
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
