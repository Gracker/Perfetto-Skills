GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/android_view_multi_window.skill.yaml
Source SHA-256: a73acb224cc9432726d218f192479028cad43d63da2711bb1f53edbd0aee9836
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# Android View 多窗口

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_android_view_multi_window
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: ANDROID_VIEW_MULTI_WINDOW
display_name: Android View 多窗口
description: 同进程多窗口渲染 (Dialog/PopupWindow)，RenderThread 串行化
icon: window
family: hwui
doc_path: rendering_pipelines/android_view_multi_window.md
s_article_ref: S06
four_features:
  producer_threads:
  - main
  - RenderThread
  expected_layer_count: 2
  bufferqueue_path: BBQ_TRANSACTION_INPROC_MULTIPLE
  extra_rhythm_sources: []
deviation_anchors: serialized_multi_viewroot_anchor_2_3_4_5
non_primary_note: '此 pipeline ID 已在代码 NON_PRIMARY_PIPELINE_IDS（renderingPipelineDetectionSkillGenerator.ts:23）

  中注册，不会被选为 primary，只会出现在 features list。

  '
subvariants_note: '文章 S06 严格区分（按窗口形态 + 进程拓扑两条轴）：

  - MULTI_WINDOW_SAME_PROCESS（Dialog/PopupWindow/同 App 多 Activity/Activity Embedding）— 当前 ID 主要覆盖

  - MULTI_WINDOW_SPLIT_SCREEN（分屏，通常跨进程）

  - MULTI_WINDOW_PIP（Picture in Picture）

  - MULTI_WINDOW_FREEFORM（自由窗口/桌面模式）

  Phase E 拆分独立 ID。

  决定性信号（同进程）：trace 同一 main thread 看到多次 performTraversals。

  YAML 当前不支持"同 doFrame 内多次出现"语义，留 Phase B 主决策树用 SQL 时间窗口分组实现。

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
- signal: has_dialog
  slice_pattern: '*Dialog*'
  weight: 20
- signal: has_popup_window
  slice_pattern: '*PopupWindow*'
  weight: 20
- signal: has_draw_frame
  slice_pattern: DrawFrame*
  weight: 20
- signal: has_perform_traversals_multi
  slice_pattern: '*performTraversals*'
  weight: 12
  min_count: 2
```

## Teaching model

```yaml
title: Android View 多窗口渲染管线
summary: '同进程内存在多个窗口 (Dialog, PopupWindow, Toast)。由于共用一个 RenderThread，

  多个窗口的渲染会串行化，可能导致帧率下降。需要关注窗口渲染顺序和时间分配。

  '
mermaid: "sequenceDiagram\n  participant VA as VSync-app\n  participant Main as App (main)\n  participant RT as RenderThread\n\
  \  participant BQ1 as BufferQueue (Main)\n  participant BQ2 as BufferQueue (Dialog)\n  participant VS as VSync-sf\n  participant\
  \ SF as SurfaceFlinger\n\n  Note over VA,SF: \U0001F4CD Multi-Window (Dialog/PopupWindow)\n  VA->>Main: \U0001F514 VSync-app\n\
  \  activate Main\n  Main->>Main: 主窗口 Layout + Draw\n  Main->>RT: syncFrameState (主窗口)\n  Main->>Main: Dialog Layout + Draw\n\
  \  Main->>RT: syncFrameState (Dialog)\n  deactivate Main\n\n  activate RT\n  Note over RT: ⏱️ 串行处理多窗口\n  RT->>BQ1: queueBuffer\
  \ (主窗口)\n  RT->>BQ2: queueBuffer (Dialog)\n  deactivate RT\n\n  VS->>SF: \U0001F514 VSync-sf\n  activate SF\n  SF->>SF:\
  \ latchBuffer (多 Surface)\n  SF->>SF: HWC 合成\n  deactivate SF\n\n  Note over VA,SF: ⚠️ RenderThread 串行化可能导致卡顿\n"
thread_roles:
- thread: main
  role: 多窗口 UI 管理
  description: 管理多个窗口的 View 树
- thread: RenderThread
  role: 渲染线程 (串行)
  description: 串行渲染多个窗口，可能成为瓶颈
key_slices:
- name: Dialog
  thread: any
  description: 对话框相关操作
- name: PopupWindow
  thread: any
  description: 弹出窗口操作
- name: Choreographer#doFrame
  thread: main
  description: 同一帧内可能连续驱动多个窗口的 layout/draw
- name: syncFrameState
  thread: RenderThread
  description: 多个窗口共享 RenderThread，同步与提交容易串行化
- name: DrawFrame
  thread: RenderThread
  description: GPU 渲染阶段（多窗口会放大工作量）
```

## Analysis guidance

```yaml
common_issues:
- id: rt_serialization
  name: RenderThread 串行化
  description: 多窗口导致 RenderThread 工作量翻倍
  detection_skill: render_thread_slices
- id: traversal_callback_serialization
  name: performTraversals callback 串行竞争
  description: '同一 doFrame 内多个 ViewRootImpl 的 performTraversals 在 main thread 串行执行

    （注册顺序决定先后）。一个窗口 TRAVERSAL 变长会直接挤掉另一个窗口本帧的预算。

    S06 §"同进程场景：多个 ViewRootImpl 在同一个 doFrame() 里串行执行"。

    '
  detection_skill: app_frame_production
- id: drawframe_serialization_on_renderthread
  name: RenderThread 进程级单例下 DrawFrame 串行排队
  description: 'HWUI RenderThread 是进程级单例（RenderThread::getInstance()），

    同一进程所有窗口的 HardwareRenderer 都向同一个 RenderThread 投递任务。

    多窗口 DrawFrame slice 在 RenderThread 上串行排队，主窗口滚动 + Dialog 动画同时发生时

    哪一个先开始画对这一帧结果有影响。

    '
  detection_skill: render_thread_slices
- id: geometry_visibility_change_late
  name: 窗口几何/可见性变化与 buffer 更新不同帧生效
  description: '窗口大小/位置/可见性/裁剪通过 SurfaceControl.Transaction 进入系统。

    SurfaceSyncGroup（API 34+）/ sync transaction 能让几何与 buffer 同帧生效，

    但应用还没 draw / fence 未 ready / 跨进程 Producer 节奏不可控时，目标帧仍可能错过。

    '
  detection_skill: sf_composition_in_range
- id: same_process_callback_order_dependency
  name: callback 注册顺序决定窗口先后
  description: 'Choreographer.doFrame() 按 callback 注册顺序依次执行 pending callbacks——

    先注册的窗口先执行，后注册的被挤后。Dialog 弹出时机不同会改变后续帧的 callback 顺序。

    '
  detection_skill: app_frame_production
recommended_skills:
- render_thread_slices
- jank_frame_detail
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
