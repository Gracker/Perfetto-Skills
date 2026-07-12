GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/android_view_standard_legacy.skill.yaml
Source SHA-256: 6a2d7cacb8c3467eaf412df95cd45a6ca4669844f8b4fcf6279decc5f1251208
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d
# 标准 Android View (Legacy)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_android_view_standard_legacy
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: ANDROID_VIEW_STANDARD_LEGACY
display_name: 标准 Android View (Legacy)
description: Android 12 之前的 HWUI + Legacy BufferQueue 渲染管线
icon: android
family: hwui
doc_path: rendering_pipelines/android_view_standard.md
s_article_ref: S02
four_features:
  producer_threads:
  - RenderThread
  expected_layer_count: 1
  bufferqueue_path: BUFFERQUEUE_INPROC
  extra_rhythm_sources: []
deviation_anchors: baseline_legacy_no_blast_anchor_6
```

## Detection

```yaml
required_signals:
- thread: RenderThread
  min_count: 1
- thread: main
  min_count: 1
scoring_signals:
- signal: has_queue_buffer
  slice_pattern: '*queueBuffer*'
  weight: 30
- signal: has_dequeue_buffer
  slice_pattern: '*dequeueBuffer*'
  weight: 20
- signal: has_draw_frame
  slice_pattern: DrawFrame*
  weight: 25
exclude_if:
- slice_pattern: '*BLASTBufferQueue*'
- slice_pattern: '*applyTransaction*'
- thread: 1.ui
- thread: CrRendererMain
- thread: UnityMain
- thread: UnityGfx
```

## Teaching model

```yaml
title: Android View 标准渲染管线 (Legacy)
summary: 'Android 12 之前的默认渲染管线，使用 HWUI 硬件加速和传统 BufferQueue 机制。

  Buffer 通过 Binder 调用提交给 SurfaceFlinger，缺少原子性事务支持。

  '
mermaid: "sequenceDiagram\n  participant VA as VSync-app\n  participant Main as App (main)\n  participant RT as RenderThread\n\
  \  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\n  Note over VA,SF:\
  \ \U0001F4CD Frame N Production Phase (Legacy)\n  VA->>Main: \U0001F514 VSync-app 信号触发\n  activate Main\n  Main->>Main:\
  \ Choreographer#doFrame\n  Main->>Main: Input → Animation → Measure → Layout → Draw\n  Main->>RT: syncFrameState (阻塞)\n\
  \  deactivate Main\n\n  activate RT\n  RT->>BQ: dequeueBuffer\n  RT->>RT: DrawFrame (GPU 渲染)\n  RT->>BQ: queueBuffer (Binder\
  \ 调用)\n  deactivate RT\n\n  Note over BQ,SF: \U0001F4CD Frame N Consumption Phase\n  BQ-->>SF: onFrameAvailable 回调\n  VS->>SF:\
  \ \U0001F514 VSync-sf 信号触发\n  activate SF\n  SF->>SF: handleMessageRefresh\n  SF->>SF: latchBuffer\n  SF->>SF: HWC Composite\n\
  \  deactivate SF\n\n  Note over VA,SF: ⚠️ Legacy 缺少原子事务，可能出现撕裂/尺寸不同步\n"
thread_roles:
- thread: main
  role: UI 构建
  description: Measure/Layout/Draw 生成 DisplayList
- thread: RenderThread
  role: GPU 渲染
  description: 执行绘制命令，通过 BufferQueue 提交
- thread: SurfaceFlinger
  role: 合成显示
  description: Latch Buffer，HWC 合成
key_slices:
- name: DrawFrame
  thread: RenderThread
  description: 开始渲染
- name: queueBuffer
  thread: RenderThread
  description: 提交 Buffer 到 BufferQueue
- name: dequeueBuffer
  thread: RenderThread
  description: 获取空闲 Buffer
```

## Analysis guidance

```yaml
common_issues:
- id: buffer_stall
  name: Buffer 等待
  description: 等待 BufferQueue 可用 Buffer
  detection_skill: render_thread_slices
- id: tearing_or_size_desync
  name: 撕裂或尺寸错位
  description: 'Legacy BufferQueue 缺乏 BLAST 的原子事务保证——几何变化（位置/尺寸/裁剪）

    与 buffer 更新不在同一帧生效时，用户能看到撕裂或尺寸错位一帧。

    升级到 Android 12+/BLAST 路径可显著改善此类问题。

    '
  detection_skill: sf_composition_in_range
- id: binder_submit_overhead
  name: Binder 提交开销
  description: 'Legacy 路径下 buffer 通过 Binder 调用从 App 进程提交给 SurfaceFlinger，

    相比 BLAST in-process Transaction 多一次跨进程通信开销，对短帧预算敏感。

    '
  detection_skill: render_thread_slices
recommended_skills:
- scrolling_analysis
- jank_frame_detail
- render_thread_slices
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
    detection_sql: 'SELECT DISTINCT p.name as process_name, COUNT(*) as slice_count

      FROM slice s

      JOIN thread_track tt ON s.track_id = tt.id

      JOIN thread t ON tt.utid = t.utid

      JOIN process p ON t.upid = p.upid

      WHERE t.name = ''RenderThread'' AND s.name GLOB ''DrawFrame*''

      GROUP BY p.upid HAVING slice_count > 10

      '
- pattern: BufferQueue
  match_by: name
  priority: 4
  reason: BufferQueue (传输)
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程相关的 BufferQueue 轨道
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
