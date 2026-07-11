GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/compose_standard.skill.yaml
Source SHA-256: a864dbf8dba46dab81928bb99d5a99bb6629001b5135dee571ed40856017f588
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# Jetpack Compose (Standard)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_compose_standard
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: COMPOSE_STANDARD
display_name: Jetpack Compose (Standard)
description: Jetpack Compose + HWUI RenderThread, Recomposition driven
icon: android
family: hwui
doc_path: rendering_pipelines/compose_standard.md
s_article_ref: S02
four_features:
  producer_threads:
  - RenderThread
  expected_layer_count: 1
  bufferqueue_path: BBQ_TRANSACTION_INPROC
  extra_rhythm_sources: []
deviation_anchors: baseline_compose_main_thread_form_only
compose_specific: true
compose_tracing_dependency_note: 'Compose 特有 slice 需要启用 androidx.compose.runtime:runtime-tracing

  （Compose UI 1.3.0+, Studio Flamingo+, API 30+）。

  未启用 tracing 时只能看到笼统的 ComposeView#onMeasure / onLayout / onDraw 这种宿主 View 回调 slice，

  看不到 Composable 函数级细节。排查 Compose 性能问题前先确认 tracing 已开启。

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
- signal: has_recomposition
  slice_pattern: Recompos*
  weight: 80
- signal: has_compose_prefix
  slice_pattern: Compose:*
  weight: 40
- signal: has_composition_local
  slice_pattern: '*CompositionLocal*'
  weight: 30
- signal: has_measure_layout
  slice_pattern: '*measure*'
  weight: 10
- signal: has_draw_frame
  slice_pattern: DrawFrame*
  weight: 15
exclude_if:
- thread: 1.ui
- thread: CrRendererMain
```

## Teaching model

```yaml
title: Jetpack Compose 渲染管线
summary: 'Jetpack Compose 基于 HWUI RenderThread 渲染，但在 UI 构建阶段有独特的机制：

  - Composition 阶段: Recomposer 驱动 @Composable 函数重新执行

  - Layout 阶段: Compose 自有的 measure/layout (非 View.onMeasure)

  - Draw 阶段: 生成 DisplayList, 由 RenderThread 执行 GPU 渲染


  性能关键点:

  - Recomposition 风暴: 不必要的重组导致频繁重绘

  - State 读取范围: 过宽的 State 读取触发过多组件重组

  - LazyColumn/LazyRow: 类似 RecyclerView 的虚拟化列表

  '
mermaid: "sequenceDiagram\n  participant VA as VSync-app\n  participant Main as Main Thread\n  participant RC as Recomposer\n\
  \  participant RT as RenderThread\n  participant BQ as BLASTBufferQueue\n  participant VS as VSync-sf\n  participant SF\
  \ as SurfaceFlinger\n\n  Note over VA,SF: Jetpack Compose (HWUI + BLAST)\n  VA->>Main: VSync -> Choreographer#doFrame\n\
  \  activate Main\n  Main->>RC: Recomposition (State changed)\n  RC->>RC: @Composable functions\n  RC->>Main: Layout (measure\
  \ + place)\n  Main->>Main: Draw (Canvas -> DisplayList)\n  Main->>RT: syncFrameState\n  deactivate Main\n\n  activate RT\n\
  \  RT->>RT: DrawFrame (GPU commands)\n  RT->>BQ: queueBuffer + applyTransaction\n  deactivate RT\n\n  VS->>SF: VSync-sf\n\
  \  activate SF\n  SF->>SF: latchBuffer + Composite\n  deactivate SF\n"
thread_roles:
- thread: main
  role: Composition + Layout + Draw
  description: Recomposer 驱动 Composable 函数, Layout, 生成 DisplayList
  trace_tags:
  - Recompos*
  - Compose:*
  - Choreographer#doFrame
- thread: RenderThread
  role: GPU 渲染
  description: 执行 DisplayList -> GPU 命令 -> queueBuffer
  trace_tags:
  - DrawFrame
  - syncFrameState
  - queueBuffer
- thread: SurfaceFlinger
  role: 合成显示
  description: BLAST Transaction 接收, HWC/GPU 合成
key_slices:
- name: Recomposition
  thread: main
  description: Compose 重组 -- 当 State 变化时触发, 是性能问题的主要来源
- name: Compose:*
  thread: main
  description: Compose 内部操作 (CompositionLocal, SnapshotState 等)
- name: Choreographer#doFrame
  thread: main
  description: 帧开始, 驱动 Composition -> Layout -> Draw
- name: DrawFrame
  thread: RenderThread
  description: GPU 渲染, 执行 DisplayList
- name: syncFrameState
  thread: RenderThread
  description: Main -> RenderThread 同步 DisplayList (阻塞 Main)
```

## Analysis guidance

```yaml
common_issues:
- id: recomposition_storm
  name: Recomposition 风暴
  description: 不必要的频繁重组, 通常由 State 读取范围过宽导致
  detection_skill: scrolling_analysis
- id: heavy_composition
  name: 重量级 Composition
  description: 单帧 Composition 阶段耗时过长
  detection_skill: jank_frame_detail
- id: non_skippable_recomposition
  name: 非 skippable Composable 频繁重组
  description: 'Composable 参数不 stable（如普通 List<T>、未加注解的 data class、捕获不稳定状态的 lambda），

    Compose 编译器无法将其标记为 skippable。即使参数内容没变，每次 state change 都会重组。

    定位手段：Compose Compiler stability report 或 Layout Inspector 重组计数。

    '
  detection_skill: app_frame_production
- id: subcompose_layout_multipass
  name: SubcomposeLayout / intrinsic measurements 多 pass
  description: 'Compose 默认是一次 measure/layout 遍历（single-pass），但 SubcomposeLayout / intrinsic measurements

    / Lookahead 这些机制会带来额外 pass。深嵌套使用时主线程 Layout 阶段时间会被放大。

    '
  detection_skill: app_frame_production
- id: state_read_scope_too_wide
  name: State 读取范围过宽
  description: 'State 读取范围过宽，触发过多 Composable 重组——典型如顶层 ViewModel 字段被多个 Composable 读取，

    某个字段变化引发整页重组。修复：用 derivedStateOf / 拆分 State 缩小读取作用域。

    '
  detection_skill: app_frame_production
recommended_skills:
- scrolling_analysis
- jank_frame_detail
- render_pipeline_latency
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
  reason: Composition + Layout + Draw (生产)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 有 Compose 重组活动的进程
    detection_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as recomp_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'main'\n\
      \  AND s.name GLOB 'Recompos*'\n  AND p.name IS NOT NULL\nGROUP BY p.upid\nHAVING recomp_count > 3\nORDER BY recomp_count\
      \ DESC\nLIMIT 10\n"
- pattern: ^RenderThread(\s+\d+)?$
  match_by: name
  priority: 3
  reason: GPU 渲染 (传输)
  expand: true
  smart_filter:
    enabled: true
    detection_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as frame_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB 'DrawFrame*'\n  AND p.name IS NOT NULL\nGROUP BY p.upid\nHAVING frame_count > 5\n"
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
