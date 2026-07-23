GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/android_view_standard_blast.skill.yaml
Source SHA-256: 78d0c2c42588b16a4a9fd020bd57a3ab3dd13c448ab9e726b3878ae30427e6b0
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
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
doc_path: rendering_pipelines/S02_aosp_standard_type.md
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
source: rendering_pipelines/S02_aosp_standard_type.md
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
