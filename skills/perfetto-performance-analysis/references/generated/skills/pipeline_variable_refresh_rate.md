GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/variable_refresh_rate.skill.yaml
Source SHA-256: 95cd800c2776cc4d8f2efcc6782e82eb8e61996346303edf2c0e6fce7c8ba554
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# 可变刷新率 (VRR)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_variable_refresh_rate
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: VARIABLE_REFRESH_RATE
display_name: 可变刷新率 (VRR)
description: VRR/ARR + FrameTimeline 动态刷新率
icon: refresh
family: specialized
doc_path: rendering_pipelines/variable_refresh_rate.md
s_article_ref: S01
four_features:
  producer_threads: []
  expected_layer_count: any
  bufferqueue_path: ANY
  extra_rhythm_sources:
  - setFrameRate_API
  - setFrameRateCategory_API
  - ARR_hardware_support
deviation_anchors: cross_cutting_feature_at_anchor_7_to_12
non_primary_note: '此 pipeline_id 已在 NON_PRIMARY_PIPELINE_IDS 中，且使用 GLOBAL_SCOPE_PIPELINE_IDS（信号在 SF 进程而不是 App 进程）。

  Detection 改动只影响 features list。

  '
api_evolution: '版本演进：

  - Android 11+: Surface.setFrameRate（声明 surface 期望帧率）

  - Android 14+: View.setRequestedFrameRate / Compose Modifier.requestedFrameRate（View 级帧率优先级）

  - Android 16+: Display.hasArrSupport / Display.getSuggestedFrameRate（主动查询 ARR 能力）

  '
jank_decoupling: 'VRR/ARR 节省的是功耗、抖动和高频段浪费，不是 deadline。

  一帧已经 miss deadline 时改变刷新率不能救它（FrameTimeline expected_frame_timeline_slice 仍按当前刷新率算 deadline）。

  '
```

## Detection

```yaml
required_signals:
- thread: SurfaceFlinger
  min_count: 1
scoring_signals:
- signal: has_frame_timeline
  slice_pattern: '*FrameTimeline*'
  min_count: 5
  weight: 40
- signal: has_set_frame_rate
  slice_pattern: '*setFrameRate*'
  weight: 15
- signal: has_frame_rate_vote
  slice_pattern: '*FrameRateVote*'
  weight: 5
- signal: has_set_frame_rate_category
  slice_pattern: '*setFrameRateCategory*'
  weight: 6
- signal: has_frame_rate_category
  slice_pattern: '*FRAME_RATE_CATEGORY*'
  weight: 6
- signal: has_display_mode
  slice_pattern: '*DisplayMode*'
  weight: 8
- signal: has_refresh_rate
  slice_pattern: '*RefreshRate*'
  weight: 7
```

## Teaching model

```yaml
title: 可变刷新率 (VRR) 渲染管线
summary: '可变刷新率 (VRR/ARR) 允许屏幕动态调整刷新率以匹配内容帧率。

  结合 FrameTimeline，系统可以精确追踪每一帧的预期和实际显示时间，

  实现更流畅的显示效果和更好的功耗表现。API 名称、可用性和

  切换策略依 Android 版本、设备和 OEM 实现变化，不应把单个 slice 名当成稳定 contract。


  关键机制（随 Android 版本持续演进）:

  - Android 11+：应用侧可通过 Surface.setFrameRate 表达“期望帧率/稳定性/场景”（具体能力依设备）

  - SurfaceFlinger 汇总多层的帧率偏好，做 DisplayMode/刷新率决策

  - FrameTimeline 让“生产-合成-显示”的帧节拍可观测，便于定位抖动来源

  '
mermaid: "sequenceDiagram\n  participant App as App\n  participant RT as RenderThread\n  participant FT as FrameTimeline\n\
  \  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n  participant Disp as\
  \ Display (VRR)\n\n  Note over App,SF: \U0001F4CD Variable Refresh Rate (VRR/ARR)\n  Note over App: setFrameRate (一次性声明期望帧率)\n\
  \  App->>RT: syncFrameState\n\n  activate RT\n  RT->>RT: DrawFrame\n  RT->>BQ: queueBuffer + presentTime\n  deactivate RT\n\
  \n  FT-->>SF: FrameTimeline 信息\n  VS->>SF: \U0001F514 VSync-sf (动态间隔)\n  activate SF\n  SF->>SF: latchBuffer\n  SF->>SF:\
  \ 检查 FrameTimeline\n  SF->>Disp: 按内容帧率刷新\n  deactivate SF\n\n  Note over App,SF: \U0001F4FA 支持 30/60/90/120Hz 等动态帧率切换\n"
thread_roles:
- thread: main
  role: UI 构建
  description: 应用 UI 渲染
- thread: RenderThread
  role: 帧渲染
  description: GPU 渲染和帧提交
- thread: SurfaceFlinger
  role: VRR 控制
  description: 动态刷新率控制
key_slices:
- name: FrameTimeline
  thread: any
  description: 帧时间线追踪
- name: setFrameRate
  thread: any
  description: 应用表达期望帧率/稳定性（具体 trace 名称与实现有关）
- name: setFrameRateCategory
  thread: any
  description: 帧率分类/场景提示（不同版本/厂商实现可能不同）
- name: FrameRateVote
  thread: SurfaceFlinger
  description: 可能出现的帧率投票提示信号
```

## Analysis guidance

```yaml
common_issues:
- id: vrr_miss
  name: VRR 目标未达
  description: 帧率低于 VRR 目标刷新率
  detection_skill: jank_frame_detail
- id: vrr_does_not_save_jank
  name: VRR 不能救 missed deadline 的帧
  description: 'VRR/ARR 改的是显示策略（功耗/抖动/高频段浪费），不改单帧的 deadline。

    FrameTimeline expected_frame_timeline_slice 仍按当前刷新率算 deadline，

    生产或合成超 budget 时 jank 该出现还是出现。

    '
  detection_skill: jank_frame_detail
- id: setframerate_called_excessively
  name: setFrameRate 调用过频
  description: 'setFrameRate 是声明性 API（一次性表达期望帧率），频繁调用引发 SurfaceFlinger 反复重投票 DisplayMode，

    增加 SF 开销。设计上应一次性声明，仅在场景切换时调整。

    '
  detection_skill: sf_frame_consumption
- id: framerate_vote_competition_multi_layer
  name: 多 layer 帧率投票竞争
  description: '多 layer 同时活跃时（视频 30fps + UI 60fps + IME 120Hz）SF 需协调最终 DisplayMode。

    投票策略由 SF 决定，可能不是简单取最高。S01 §"应用侧能影响刷新率的入口"。

    '
  detection_skill: sf_layer_count_in_range
recommended_skills:
- scrolling_analysis
- jank_frame_detail
- vrr_detection
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
  reason: UI 构建 (生产)
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
  reason: 帧渲染 (传输)
  expand: true
  smart_filter:
    enabled: true
    detection_sql: "SELECT DISTINCT p.name as process_name, COUNT(*) as frame_count\nFROM slice s\nJOIN thread_track tt ON\
      \ s.track_id = tt.id\nJOIN thread t ON tt.utid = t.utid\nJOIN process p ON t.upid = p.upid\nWHERE t.name = 'RenderThread'\n\
      \  AND s.name GLOB 'DrawFrame*'\n  AND p.name IS NOT NULL\nGROUP BY p.upid\nHAVING frame_count > 5\n"
- pattern: VSYNC
  match_by: name
  priority: 4
  reason: 动态刷新率
- pattern: FrameTimeline
  match_by: name
  priority: 5
  reason: 帧时间线
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
  reason: VRR 合成/显示
  main_thread_only: true
```
