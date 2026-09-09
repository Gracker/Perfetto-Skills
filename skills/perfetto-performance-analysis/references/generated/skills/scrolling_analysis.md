GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/scrolling_analysis.skill.yaml
Source SHA-256: 2dcba698d9cc63e045e9346afc44cab60148cf55a58161bf0378383d624af4ff
Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38
# 滑动性能分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: scrolling_analysis
version: '2.2'
type: composite
tier: S
```

## Metadata

```yaml
display_name: 滑动性能分析
description: 沿实际主线程连续执行追查动画/滑动任务与等待，再用 FrameTimeline 和 android.input 核对出帧结果
icon: swipe
tags:
- scrolling
- jank
- fps
- frames
- input
- latency
- layered
```

## Triggers

```yaml
keywords:
  zh:
  - 滑动
  - 卡顿
  - 帧率
  - 掉帧
  - 丢帧
  - FPS
  - 流畅度
  - 列表滑动
  - fling
  - 输入延迟
  - 触摸延迟
  - 跟手
  en:
  - scroll
  - jank
  - fps
  - frame
  - fling
  - stutter
  - smoothness
  - list
  - input latency
  - touch latency
  - follow finger
patterns:
- .*滑动.*卡.*
- .*scroll.*jank.*
- .*帧率.*
```

## Prerequisites

```yaml
modules:
- android.input
- android.frames.timeline
- android.frames.jank_type
- android.binder
- android.garbage_collection
- android.monitor_contention
```

## Inputs

```yaml
- name: main_thread_top_k
  type: number
  required: false
  default: 20
  description: 主线程根任务/观测间隔输出上限，1～100；不截断完整窗口统计
- name: package
  type: string
  required: false
  description: 应用包名（可选，不填则分析所有应用）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
- name: enable_frame_details
  type: boolean
  required: false
  description: 是否执行逐帧详情分析（L4，默认不执行）
- name: max_frames_per_session
  type: number
  required: false
  description: 每个滑动区间最多返回的掉帧帧数（默认 200，配合 batch_frame_root_cause 批量分类）
- name: enable_expert_probes
  type: boolean
  required: false
  default: true
  description: 是否启用专家探针（帧方差等）
- name: frame_variance_probe_min_janky_frames
  type: number
  required: false
  default: 5
  description: 触发帧方差探针的最小掉帧数
- name: frame_variance_transition_threshold_ms
  type: number
  required: false
  default: 8
  description: 帧间高抖动阈值（ms）
- name: input_handling_budget_ratio
  type: number
  required: false
  default: 0.5
  description: 输入处理慢判定阈值：占当前 VSync 帧预算的比例（默认 50%）
- name: input_event_backlog_threshold
  type: number
  required: false
  default: 3
  description: 同帧输入事件堆积候选阈值（默认 3，必须同时有处理耗时证据才作为根因）
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
- process_name
rewriteTo: recommended_process_name_param
```

## Ordered execution

### 主线程全窗口与帧内外状态

- ID: `main_thread_work_summary`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/main_thread_work_summary.sql`](../sql/scrolling_analysis/main_thread_work_summary.sql)

```yaml
id: main_thread_work_summary
type: atomic
process_scope:
  role: target
  binding: effective_target_processes
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/main_thread_work.sql
save_as: main_thread_work_summary
synthesize:
  role: overview
  fields:
  - key: annotated_wall_ms
    label: 主线程有标注区间(ms)
  - key: unannotated_running_ms
    label: 主线程无slice标注的Running(ms)
  - key: unknown_state_ms
    label: 主线程调度状态未知(ms)
  insights:
  - template: 主线程连续窗口：UPID={{upid}} UTID={{utid}}，{{eligible_task_count}}个观测根任务、{{observed_doframe_count}}个doFrame；状态未知{{unknown_state_ms}}ms。未观测到doFrame不代表没有渲染请求。
display:
  level: summary
  layer: overview
  title: 主线程连续窗口（wall time与调度状态）
  columns:
  - name: phase
    label: 区间
    type: string
  - name: wall_ms
    label: 区间时长
    type: duration
    format: duration_ms
    unit: ms
  - name: annotated_wall_ms
    label: 有slice标注
    type: duration
    format: duration_ms
    unit: ms
  - name: running_ms
    label: Running
    type: duration
    format: duration_ms
    unit: ms
  - name: runnable_ms
    label: Runnable
    type: duration
    format: duration_ms
    unit: ms
  - name: runnable_preempted_ms
    label: 抢占后Runnable
    type: duration
    format: duration_ms
    unit: ms
  - name: sleep_ms
    label: S等待
    type: duration
    format: duration_ms
    unit: ms
  - name: idle_state_ms
    label: I状态
    type: duration
    format: duration_ms
    unit: ms
  - name: uninterruptible_ms
    label: D等待
    type: duration
    format: duration_ms
    unit: ms
  - name: uninterruptible_wakekill_ms
    label: DK等待
    type: duration
    format: duration_ms
    unit: ms
  - name: io_wait_ms
    label: 已标记IO等待
    type: duration
    format: duration_ms
    unit: ms
  - name: unknown_state_ms
    label: 未知状态
    type: duration
    format: duration_ms
    unit: ms
  - name: unannotated_running_ms
    label: 无标注Running
    type: duration
    format: duration_ms
    unit: ms
  - name: ambiguous_annotation_wall_ms
    label: 根标注重叠
    type: duration
    format: duration_ms
    unit: ms
  - name: incomplete_slice_count
    label: 未结束slice
    type: number
  - name: upid
    label: UPID
    type: number
  - name: utid
    label: UTID
    type: number
  - name: window_start_ts
    label: 窗口起点
    type: timestamp
    unit: ns
  - name: window_end_ts
    label: 窗口终点
    type: timestamp
    unit: ns
  - name: unannotated_wall_ms
    label: 无标注时长
    type: duration
    format: duration_ms
    unit: ms
  - name: known_state_ms
    label: 已知调度状态
    type: duration
    format: duration_ms
    unit: ms
  - name: conflicting_state_ms
    label: 冲突调度状态
    type: duration
    format: duration_ms
    unit: ms
  - name: other_state_ms
    label: 其他调度状态
    type: duration
    format: duration_ms
    unit: ms
  - name: unknown_io_wait_ms
    label: D或DK的IO属性未知
    type: duration
    format: duration_ms
    unit: ms
  - name: eligible_task_count
    label: 全部根任务
    type: number
  - name: observed_doframe_count
    label: 观测doFrame数
    type: number
  - name: evidence_scope
    label: 证据范围
    type: string
```
### 主线程任务与来源定位

- ID: `main_thread_work_tasks`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/main_thread_work_tasks.sql`](../sql/scrolling_analysis/main_thread_work_tasks.sql)

```yaml
id: main_thread_work_tasks
type: atomic
process_scope:
  role: target
  binding: effective_target_processes
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/main_thread_work.sql
- fragments/main_thread_work_tasks.sql
save_as: main_thread_work_tasks
synthesize:
  role: list
  fields:
  - key: task_name
    label: 主线程任务
  - key: outside_doframe_ms
    label: doFrame外耗时(ms)
  - key: slice_id
    label: 定位slice
  groupBy:
  - field: task_name
    title: 主线程观测任务
  insights:
  - template: 主线程任务{{task_name}}：{{phase}}，doFrame外{{outside_doframe_ms}}ms，Running={{running_ms}}ms Runnable={{runnable_ms}}ms，状态未知{{unknown_state_ms}}ms（null表示未知），slice={{slice_id}}
      UPID={{upid}} UTID={{utid}} ts={{start_ts}}；热点{{hotspot_name}}，slice={{hotspot_slice_id}} arg_set={{hotspot_arg_set_id}}，exclusive
      wall={{hotspot_exclusive_wall_ms}}ms。已返回{{returned_task_count}}/{{eligible_task_count}}个根任务；main_thread_work_sources保留前三热点/等待定位，需结合请求证据判断因果。
display:
  level: summary
  layer: list
  title: 主线程任务（含帧间任务与来源）
  columns:
  - name: task_name
    label: 任务标注
    type: string
  - name: phase
    label: 与doFrame的关系
    type: string
  - name: outside_doframe_ms
    label: doFrame外
    type: duration
    format: duration_ms
    unit: ms
  - name: wall_ms
    label: 观测时长
    type: duration
    format: duration_ms
    unit: ms
  - name: running_ms
    label: Running
    type: duration
    format: duration_ms
    unit: ms
  - name: hotspot_name
    label: 子热点标注
    type: string
  - name: hotspot_exclusive_wall_ms
    label: 子热点exclusive wall
    type: duration
    format: duration_ms
    unit: ms
  - name: start_ts
    label: 起点
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: slice_id
    label: 任务slice
    type: number
  - name: hotspot_slice_id
    label: 子热点slice
    type: number
  - name: arg_set_id
    label: 参数集
    type: number
  - name: ancestor_path
    label: 标注调用路径
    type: string
  - name: attribution
    label: 归属范围
    type: string
  - name: is_incomplete
    label: 未结束标注
    type: number
  - name: eligible_task_count
    label: 全部根任务
    type: number
  - name: returned_task_count
    label: 已返回根任务
    type: number
  - name: upid
    label: UPID
    type: number
  - name: utid
    label: UTID
    type: number
  - name: track_id
    label: 轨道
    type: number
  - name: parent_id
    label: 父slice
    type: number
  - name: end_ts
    label: 终点
    type: timestamp
    unit: ns
  - name: raw_ts
    label: 原始起点
    type: timestamp
    unit: ns
  - name: raw_dur
    label: 原始时长
    type: duration
    unit: ns
  - name: runnable_ms
    label: Runnable
    type: duration
    format: duration_ms
    unit: ms
  - name: runnable_preempted_ms
    label: 抢占后Runnable
    type: duration
    format: duration_ms
    unit: ms
  - name: sleep_ms
    label: S等待
    type: duration
    format: duration_ms
    unit: ms
  - name: idle_state_ms
    label: I状态
    type: duration
    format: duration_ms
    unit: ms
  - name: uninterruptible_ms
    label: D或DK等待
    type: duration
    format: duration_ms
    unit: ms
  - name: io_wait_ms
    label: 已标记IO等待
    type: duration
    format: duration_ms
    unit: ms
  - name: unknown_io_wait_ms
    label: IO属性未知
    type: duration
    format: duration_ms
    unit: ms
  - name: unknown_state_ms
    label: 未知调度状态
    type: duration
    format: duration_ms
    unit: ms
  - name: inside_doframe_ms
    label: doFrame内
    type: duration
    format: duration_ms
    unit: ms
  - name: between_doframes_ms
    label: doFrame之间
    type: duration
    format: duration_ms
    unit: ms
  - name: before_first_doframe_ms
    label: 首次doFrame前
    type: duration
    format: duration_ms
    unit: ms
  - name: after_last_doframe_ms
    label: 最后doFrame后
    type: duration
    format: duration_ms
    unit: ms
  - name: no_doframe_ms
    label: 无doFrame观测
    type: duration
    format: duration_ms
    unit: ms
  - name: ambiguous_annotation_wall_ms
    label: 重叠根标注
    type: duration
    format: duration_ms
    unit: ms
  - name: hotspot_arg_set_id
    label: 热点参数集
    type: number
  - name: hotspot_parent_id
    label: 热点父slice
    type: number
  - name: hotspot_exclusive_outside_doframe_ms
    label: 热点帧外exclusive wall
    type: duration
    format: duration_ms
    unit: ms
  - name: top_wait_state_id
    label: 等待state ID
    type: number
  - name: top_wait_state
    label: 最长等待原状态
    type: string
  - name: top_wait_blocked_function
    label: 最长等待阻塞函数
    type: string
  - name: top_wait_io_wait
    label: 等待IO标记
    type: number
  - name: top_wait_start_ts
    label: 等待起点
    type: timestamp
    unit: ns
  - name: top_wait_end_ts
    label: 等待终点
    type: timestamp
    unit: ns
  - name: top_wait_overlap_ms
    label: 等待观测时长
    type: duration
    format: duration_ms
    unit: ms
  - name: selection_scope
    label: 采样范围
    type: string
```
### 主线程任务的热点与等待来源

- ID: `main_thread_work_sources`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/main_thread_work_sources.sql`](../sql/scrolling_analysis/main_thread_work_sources.sql)

```yaml
id: main_thread_work_sources
type: atomic
process_scope:
  role: target
  binding: effective_target_processes
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/main_thread_work.sql
- fragments/main_thread_work_tasks.sql
save_as: main_thread_work_sources
display:
  level: detail
  layer: list
  title: 任务来源（每个采样任务前三热点/等待，不可相加）
  columns:
  - name: source_kind
    label: 证据类型
    type: string
  - name: root_slice_id
    label: 所属任务slice
    type: number
  - name: source_name
    label: 来源标注
    type: string
  - name: source_slice_id
    label: 来源slice
    type: number
  - name: thread_state_id
    label: 调度state ID
    type: number
  - name: state
    label: 原调度状态
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: io_wait
    label: 原IO标记
    type: number
  - name: start_ts
    label: 观测起点
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: end_ts
    label: 观测终点
    type: timestamp
    unit: ns
  - name: dur
    label: 观测时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: exclusive_wall_ms
    label: 热点exclusive wall
    type: duration
    format: duration_ms
    unit: ms
  - name: exclusive_outside_doframe_ms
    label: 热点帧外exclusive wall
    type: duration
    format: duration_ms
    unit: ms
  - name: wait_overlap_ms
    label: 等待重叠时长
    type: duration
    format: duration_ms
    unit: ms
  - name: parent_id
    label: 来源父slice
    type: number
  - name: arg_set_id
    label: 来源参数集
    type: number
  - name: upid
    label: UPID
    type: number
  - name: utid
    label: UTID
    type: number
  - name: track_id
    label: 来源轨道
    type: number
  - name: root_track_id
    label: 任务轨道
    type: number
  - name: in_doframe_tree
    label: 属于doFrame调用树
    type: number
  - name: is_incomplete
    label: 未结束标注
    type: number
  - name: source_rank
    label: 来源排名
    type: number
  - name: evidence_scope
    label: 证据范围
    type: string
```
### doFrame观测起点间隔

- ID: `main_thread_work_cadence`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/main_thread_work_cadence.sql`](../sql/scrolling_analysis/main_thread_work_cadence.sql)

```yaml
id: main_thread_work_cadence
type: atomic
process_scope:
  role: target
  binding: effective_target_processes
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/main_thread_work.sql
- fragments/main_thread_work_cadence.sql
save_as: main_thread_work_cadence
display:
  level: detail
  layer: list
  title: doFrame起点间隔（非deadline或呈现间隔）
  columns:
  - name: observed_start_interval_ms
    label: 观测起点间隔
    type: duration
    format: duration_ms
    unit: ms
  - name: between_execution_ms
    label: 前次结束至本次开始
    type: duration
    format: duration_ms
    unit: ms
  - name: observation
    label: 观测范围
    type: string
  - name: start_ts
    label: 前次起点
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 间隔(ns)
    type: duration
    unit: ns
    hidden: true
  - name: previous_slice_id
    label: 前次slice
    type: number
  - name: slice_id
    label: 本次slice
    type: number
  - name: eligible_interval_count
    label: 全部观测间隔
    type: number
  - name: returned_interval_count
    label: 已返回间隔
    type: number
  - name: upid
    label: UPID
    type: number
  - name: utid
    label: UTID
    type: number
  - name: next_start_ts
    label: 本次起点
    type: timestamp
    unit: ns
  - name: marker_count
    label: 本次同起点标记数
    type: number
  - name: previous_marker_count
    label: 前次同起点标记数
    type: number
  - name: is_incomplete
    label: 本次标记未结束
    type: number
  - name: previous_is_incomplete
    label: 前次标记未结束
    type: number
  - name: execution_overlap_ms
    label: 观测执行重叠
    type: duration
    format: duration_ms
    unit: ms
  - name: evidence_scope
    label: 证据范围
    type: string
```
### 初始化 CPU 拓扑

- ID: `init_cpu_topology`
- Type: `skill`

```yaml
id: init_cpu_topology
type: skill
skill: cpu_topology_view
display:
  level: hidden
optional: true
```
### FrameTimeline 数据源检测

- ID: `frame_timeline_check`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/frame_timeline_check.sql`](../sql/scrolling_analysis/frame_timeline_check.sql)

```yaml
id: frame_timeline_check
type: atomic
display: false
process_scope:
  role: identity_metadata
save_as: frame_timeline
```
### Vsync 配置

- ID: `vsync_config`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/vsync_config.sql`](../sql/scrolling_analysis/vsync_config.sql)

```yaml
id: vsync_config
type: atomic
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/vsync_config.sql
display:
  level: summary
  layer: overview
  title: 显示配置
  columns:
  - name: refresh_rate_hz
    label: 刷新率
    type: number
    format: compact
  - name: vsync_period_ms
    label: VSync 周期
    type: duration
    format: duration_ms
    unit: ms
  - name: vsync_source
    label: 来源
    type: string
  - name: total_frames
    label: 总帧数
    type: number
    format: compact
process_scope:
  role: target
  binding: effective_target_processes
  context_fields:
    global_context:
    - vsync_period_ns
    - refresh_rate_hz
    - vsync_period_ms
    - vsync_source
save_as: environment
condition: frame_timeline.data[0]?.has_frame_timeline === 1
```
### BufferTX / FrameTimeline 覆盖探针

- ID: `buffer_tx_coverage_probe`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/buffer_tx_coverage_probe.sql`](../sql/scrolling_analysis/buffer_tx_coverage_probe.sql)

```yaml
id: buffer_tx_coverage_probe
type: atomic
optional: true
display: false
sql_fragments:
- fragments/vsync_config.sql
- fragments/buffer_tx_frame_production.sql
process_scope:
  role: target
  exact_unavailable: BufferTX track names do not identify a unique UPID; exact process evidence uses FrameTimeline only.
exact_sql:
  process_scope:
    role: target
    binding: effective_target_processes
    limitations:
    - BufferTX track names do not identify a unique UPID; exact process evidence uses FrameTimeline only.
  sql_fragments:
  - fragments/effective_target_processes.sql
  sql: "WITH target_presence AS (\n  SELECT COUNT(*) AS target_process_count FROM effective_target_processes\n), frame_coverage\
    \ AS (\n  SELECT COUNT(DISTINCT COALESCE(CAST(a.display_frame_token AS TEXT),\n    'surface:' || COALESCE(a.layer_name,\
    \ '') || ':' || CAST(a.surface_frame_token AS TEXT))) AS frame_timeline_frames\n  FROM actual_frame_timeline_slice a\n\
    \  JOIN effective_target_processes p ON a.upid = p.upid\n  WHERE (${start_ts} IS NULL OR a.ts >= ${start_ts})\n    AND\
    \ (${end_ts} IS NULL OR a.ts < ${end_ts})\n)\nSELECT target_process_count,\n  CASE WHEN target_process_count > 0 THEN\
    \ 'found' ELSE 'not_found' END AS target_process_status,\n  frame_timeline_frames,\n  NULL AS buffer_tx_frames, NULL AS\
    \ frame_timeline_to_buffer_tx_ratio,\n  NULL AS buffer_tx_track_id, NULL AS frame_source_track,\n  NULL AS buffer_tx_effective_span_ns,\n\
    \  CASE WHEN target_process_count = 0 THEN 'target_process_not_found'\n    WHEN frame_timeline_frames = 0 THEN 'no_frame_timeline_coverage'\n\
    \    ELSE 'frame_timeline_only_exact_upid' END AS coverage_status,\n  0 AS should_fallback,\n  'unavailable_exact_upid'\
    \ AS buffer_tx_status\nFROM target_presence CROSS JOIN frame_coverage\n"
save_as: buffer_tx_coverage
condition: frame_timeline.data[0]?.has_frame_timeline === 1
```
### 帧性能汇总

- ID: `performance_summary`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/performance_summary.sql`](../sql/scrolling_analysis/performance_summary.sql)

```yaml
id: performance_summary
type: atomic
synthesize:
  role: overview
  fields:
  - key: total_frames
    label: 总帧数
  - key: perceived_jank_frames
    label: 感知掉帧
    format: '{{value}} ({{jank_rate}}%)'
  - key: buffer_stuffing_frames
    label: Buffer Stuffing
    format: '{{value}} ({{buffer_stuffing_rate}}%)'
  - key: avg_fps
    label: 平均 FPS
  - key: app_jank
    label: App 侧掉帧
  - key: sf_jank
    label: SF 侧掉帧
  insights:
  - condition: jank_rate > 10
    template: 感知掉帧率 {{jank_rate}}% 较高，需要优化
  - condition: buffer_stuffing_rate > 50
    template: Buffer Stuffing 占比 {{buffer_stuffing_rate}}%，管线背压显著（非 App 问题）
  - condition: app_jank > sf_jank
    template: App 侧掉帧 ({{app_jank}}) 多于 SF 侧 ({{sf_jank}})
display:
  level: summary
  layer: overview
  title: 滑动性能概览
  columns:
  - name: total_frames
    label: 总帧数
    type: number
    format: compact
  - name: perceived_jank_frames
    label: 感知掉帧
    type: number
    format: compact
  - name: jank_rate
    label: 感知掉帧率
    type: percentage
    format: percentage
  - name: buffer_stuffing_frames
    label: Buffer Stuffing
    type: number
    format: compact
  - name: buffer_stuffing_rate
    label: BS 占比
    type: percentage
    format: percentage
    hidden: true
  - name: app_janky_frames
    label: App 侧掉帧
    type: number
    format: compact
  - name: sf_jank_count
    label: SF 侧掉帧
    type: number
    format: compact
  - name: actual_fps
    label: 实际 FPS
    type: number
  - name: refresh_rate
    label: 刷新率
    type: number
  - name: avg_frame_dur
    label: 平均呈现间隔
    type: duration
    format: duration_ms
    unit: ns
  - name: p95_frame_dur
    label: P95 呈现间隔
    type: duration
    format: duration_ms
    unit: ns
  - name: rating
    label: 评级
    type: string
sql_fragments:
- fragments/effective_target_processes.sql
process_scope:
  role: target
  binding: effective_target_processes
  context_fields:
    global_context:
    - refresh_rate
    - vsync_period_ms
    - vsync_source
save_as: perf_summary
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && environment.data[0]?.has_data === 1 && buffer_tx_coverage.data[0]?.coverage_status
  !== 'target_process_not_found' && buffer_tx_coverage.data[0]?.should_fallback !== 1
```
### BufferTX 帧率回退

- ID: `buffer_tx_performance_fallback`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/buffer_tx_performance_fallback.sql`](../sql/scrolling_analysis/buffer_tx_performance_fallback.sql)

```yaml
id: buffer_tx_performance_fallback
type: atomic
sql_fragments:
- fragments/vsync_config.sql
- fragments/buffer_tx_frame_production.sql
synthesize:
  role: overview
  fields:
  - key: total_frames
    label: BufferTX 产出帧
  - key: actual_fps
    label: 平均 FPS
  - key: fps_source
    label: 帧率来源
  - key: duration_sec
    label: 有效时段
  - key: frame_source_track
    label: BufferTX 证据轨道
  - key: coverage_status
    label: FrameTimeline 覆盖状态
  - key: frame_timeline_to_buffer_tx_ratio
    label: FrameTimeline 覆盖率
  - key: vsync_source
    label: VSync 证据来源
  - key: evidence_status
    label: 可交付证据范围
display:
  level: summary
  layer: overview
  title: 滑动帧率概览（BufferTX 回退）
  columns:
  - name: total_frames
    label: BufferTX 产出帧
    type: number
    format: compact
  - name: actual_fps
    label: 实际 FPS
    type: number
  - name: duration_sec
    label: 有效时段(s)
    type: number
  - name: refresh_rate
    label: 刷新率
    type: number
  - name: fps_source
    label: 帧率来源
    type: string
  - name: vsync_source
    label: VSync 证据来源
    type: string
  - name: frame_source_track
    label: BufferTX 证据轨道
    type: string
  - name: frame_timeline_to_buffer_tx_ratio
    label: FrameTimeline/BufferTX 帧数比
    type: number
  - name: coverage_status
    label: FrameTimeline 覆盖状态
    type: string
  - name: evidence_status
    label: 可交付证据范围
    type: string
  - name: rating
    label: 证据边界
    type: string
process_scope:
  role: target
  exact_unavailable: BufferTX track names do not identify a unique UPID; exact process evidence uses FrameTimeline only.
save_as: perf_summary
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && buffer_tx_coverage.data[0]?.should_fallback === 1
```
### Input 数据源回退视图

- ID: `input_data_fallback_view`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/input_data_fallback_view.sql`](../sql/scrolling_analysis/input_data_fallback_view.sql)

```yaml
id: input_data_fallback_view
type: atomic
optional: true
display: false
process_scope:
  role: identity_metadata
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && environment.data[0]?.has_data === 1
```
### Input 数据源检测

- ID: `input_data_check`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/input_data_check.sql`](../sql/scrolling_analysis/input_data_check.sql)

```yaml
id: input_data_check
type: atomic
optional: true
display:
  level: summary
  layer: overview
  title: Input 数据源
  columns:
  - name: input_data_status
    label: 状态
    type: string
  - name: total_input_events
    label: 输入事件
    type: number
    format: compact
  - name: move_events
    label: MOVE事件
    type: number
    format: compact
  - name: frame_matched_events
    label: 关联帧事件
    type: number
    format: compact
  - name: target_processes
    label: 进程数
    type: number
    format: compact
process_scope:
  role: target
  binding: native_upid
save_as: input_data
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && environment.data[0]?.has_data === 1
```
### Input 延迟概览

- ID: `input_latency_summary`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/input_latency_summary.sql`](../sql/scrolling_analysis/input_latency_summary.sql)

```yaml
id: input_latency_summary
type: atomic
optional: true
synthesize:
  role: overview
  fields:
  - key: total_input_events
    label: 输入事件
  - key: max_handling_ms
    label: 最慢 App 处理
    format: '{{value}} ms'
  - key: slow_handling_events
    label: 慢输入处理事件
  - key: max_e2e_ms
    label: 最慢 Input→Present
    format: '{{value}} ms'
  - key: input_backlog_frames
    label: 输入堆积帧
  insights:
  - condition: slow_handling_events > 0
    template: 检测到 {{slow_handling_events}} 个输入事件的 App 处理耗时超过帧预算阈值
  - condition: input_backlog_frames > 0
    template: '{{input_backlog_frames}} 个帧关联的输入事件数超过堆积候选阈值'
  - condition: speculative_frame_matches > 0
    template: '{{speculative_frame_matches}} 个输入事件使用推测帧关联，跟手度证据需降权'
display:
  level: summary
  layer: overview
  title: Input 延迟概览
  columns:
  - name: target_process
    label: 目标进程
    type: string
  - name: total_input_events
    label: 输入事件
    type: number
    format: compact
  - name: move_events
    label: MOVE事件
    type: number
    format: compact
  - name: avg_dispatch_ms
    label: 平均分发
    type: duration
    format: duration_ms
    unit: ms
  - name: p95_handling_ms
    label: P95 App处理
    type: duration
    format: duration_ms
    unit: ms
  - name: max_handling_ms
    label: 最慢App处理
    type: duration
    format: duration_ms
    unit: ms
  - name: max_e2e_ms
    label: 最慢Input→Present
    type: duration
    format: duration_ms
    unit: ms
  - name: slow_handling_events
    label: 慢处理事件
    type: number
    format: compact
  - name: input_backlog_frames
    label: 输入堆积帧
    type: number
    format: compact
  - name: speculative_frame_matches
    label: 推测帧关联
    type: number
    format: compact
  - name: input_latency_rating
    label: 评级
    type: string
process_scope:
  role: target
  binding: native_upid
  context_fields:
    global_context:
    - frame_budget_ms
save_as: input_latency
condition: input_data.data[0]?.total_input_events > 0
```
### 专家分析窗口

- ID: `expert_analysis_window`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/expert_analysis_window.sql`](../sql/scrolling_analysis/expert_analysis_window.sql)

```yaml
id: expert_analysis_window
type: atomic
display: false
sql_fragments:
- fragments/effective_target_processes.sql
process_scope:
  role: target
  binding: effective_target_processes
save_as: expert_window
condition: ${enable_expert_probes|true} == true && frame_timeline.data[0]?.has_frame_timeline === 1 && environment.data[0]?.has_data
  === 1
optional: true
```
### 帧方差探针

- ID: `frame_variance_probe`
- Type: `skill`

```yaml
id: frame_variance_probe
type: skill
skill: frame_pipeline_variance
params:
  package: ${package}
  start_ts: ${expert_window.data?.[0]?.window_start_ts ?? start_ts ?? null}
  end_ts: ${expert_window.data?.[0]?.window_end_ts ?? end_ts ?? null}
  transition_threshold_ms: ${frame_variance_transition_threshold_ms|8}
display:
  level: summary
  layer: overview
  title: 帧稳定性方差（专家探针）
  columns:
  - name: total_frames
    label: 总帧数
    type: number
  - name: avg_frame_ms
    label: 平均帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: stddev_ms
    label: 标准差
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_delta_ms
    label: 帧间波动
    type: duration
    format: duration_ms
    unit: ms
  - name: high_variance_transitions
    label: 高抖动转折
    type: number
  - name: variance_level
    label: 波动等级
    type: string
save_as: frame_variance_probe
condition: ${enable_expert_probes|true} == true && frame_timeline.data[0]?.has_frame_timeline === 1 && (perf_summary?.data?.[0]?.janky_frames
  || 0) >= (frame_variance_probe_min_janky_frames || 5)
optional: true
```
### 掉帧类型统计

- ID: `jank_type_stats`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/jank_type_stats.sql`](../sql/scrolling_analysis/jank_type_stats.sql)

```yaml
id: jank_type_stats
type: atomic
display:
  level: summary
  layer: overview
  title: 掉帧类型分布
  columns:
  - name: jank_type
    label: 掉帧类型
    type: string
  - name: count
    label: 帧数
    type: number
    format: compact
  - name: real_jank_count
    label: 实际掉帧
    type: number
    format: compact
  - name: false_positive
    label: 假阳性
    type: number
  - name: total_dur
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: avg_dur
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: responsibility
    label: 类型标签
    type: string
  - name: frame_timeline_coverage_status
    label: FrameTimeline 覆盖状态
    type: string
    hidden: true
  - name: frame_timeline_to_buffer_tx_ratio
    label: FrameTimeline/BufferTX 帧数比
    type: number
    hidden: true
  - name: evidence_scope
    label: 根因证据范围
    type: string
    hidden: true
sql_fragments:
- fragments/effective_target_processes.sql
process_scope:
  role: target
  binding: effective_target_processes
save_as: jank_stats
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && environment.data[0]?.has_data === 1
```
### 滑动区间列表

- ID: `scroll_sessions`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/scroll_sessions.sql`](../sql/scrolling_analysis/scroll_sessions.sql)

```yaml
id: scroll_sessions
type: atomic
display:
  level: detail
  layer: list
  title: 滑动区间
  expandable: true
  expandableBindSource: session_stats
  columns:
  - name: session_id
    label: 区间
    type: number
  - name: process_name
    label: 进程
    type: string
  - name: start_ts
    label: 开始时间
    type: timestamp
    clickAction: navigate_range
    durationColumn: duration
  - name: end_ts
    label: 结束时间
    type: timestamp
    clickAction: navigate_timeline
  - name: frame_count
    label: 帧数
    type: number
    format: compact
  - name: duration_ms
    label: 持续时间
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
  - name: duration
    label: 持续时间
    type: duration
    format: duration_ms
    unit: ns
  - name: avg_dur
    label: 平均帧耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: max_dur
    label: 最大帧耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: session_fps
    label: FPS
    type: number
sql_fragments:
- fragments/effective_target_processes.sql
process_scope:
  role: target
  binding: effective_target_processes
save_as: sessions
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && environment.data[0]?.has_data === 1
```
### 滑动区间统计（批量）

- ID: `session_stats_batch`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/session_stats_batch.sql`](../sql/scrolling_analysis/session_stats_batch.sql)

```yaml
id: session_stats_batch
type: atomic
optional: true
display: false
save_as: session_stats
condition: scroll_sessions.data?.length > 0
sql_fragments:
- fragments/effective_target_processes.sql
process_scope:
  role: target
  binding: effective_target_processes
  context_fields:
    global_context:
    - cpu_freq_json
```
### 区间掉帧统计

- ID: `session_jank`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/session_jank.sql`](../sql/scrolling_analysis/session_jank.sql)

```yaml
id: session_jank
type: atomic
display:
  level: detail
  layer: list
  title: 区间掉帧
  columns:
  - name: session_id
    label: 区间
    type: number
  - name: frame_count
    label: 总帧数
    type: number
    format: compact
  - name: janky_count
    label: 感知掉帧
    type: number
    format: compact
  - name: jank_rate
    label: 感知掉帧率
    type: percentage
    format: percentage
  - name: app_janky_count
    label: App 掉帧
    type: number
    format: compact
  - name: buffer_stuffing_count
    label: Buffer Stuffing
    type: number
    format: compact
  - name: max_vsync_missed
    label: 最大跳帧
    type: number
  - name: jank_types
    label: 掉帧类型
    type: string
    format: truncate
sql_fragments:
- fragments/effective_target_processes.sql
process_scope:
  role: target
  binding: effective_target_processes
save_as: session_jank_data
optional: true
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && environment.data[0]?.has_data === 1
```
### 获取真正掉帧帧

- ID: `get_app_jank_frames`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/get_app_jank_frames.sql`](../sql/scrolling_analysis/get_app_jank_frames.sql)

```yaml
id: get_app_jank_frames
type: atomic
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/root_cause_sample_cap.sql
synthesize:
  role: list
  groupBy:
  - field: jank_responsibility
    title: 责任归属分布
  - field: jank_type
    title: 掉帧类型分布
display: false
process_scope:
  role: target
  binding: effective_target_processes
save_as: app_jank_frames
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && environment?.data?.[0]?.has_data === 1 && ((perf_summary?.data?.[0]?.janky_frames
  || 0) > 0 || (jank_stats?.data?.[0]?.real_jank_count || 0) > 0)
```
### 掉帧列表（含根因分类）

- ID: `batch_frame_root_cause`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/batch_frame_root_cause.sql`](../sql/scrolling_analysis/batch_frame_root_cause.sql)

```yaml
id: batch_frame_root_cause
type: atomic
optional: true
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/vsync_config.sql
- fragments/root_cause_sample_cap.sql
synthesize:
  role: list
  groupBy:
  - field: jank_responsibility
    title: 责任归属分布
  - field: reason_code
    title: 根因分类分布
  insights:
  - template: 根因分析覆盖 {{root_cause_analyzed_frame_count}}/{{root_cause_eligible_frame_count}} 帧，coverage={{root_cause_coverage_ratio}}，每
      Session 上限 {{root_cause_sample_limit_per_session}}，scope={{root_cause_analysis_scope}}
display:
  level: detail
  layer: list
  title: 掉帧列表
  expandable: true
  expandableBindSource: batch_root_cause
  collapsible: true
  defaultCollapsed: true
  metadataFields:
  - process_name
  - pid
  columns:
  - name: frame_id
    label: 帧 ID
    type: string
  - name: frame_identity_key
    label: 帧身份键
    type: string
    hidden: true
  - name: layer_name
    label: Layer
    type: string
    hidden: true
  - name: frame_index
    label: 帧序号
    type: number
    hidden: true
  - name: start_ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 帧耗时(ns)
    type: duration
    unit: ns
    hidden: true
  - name: dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
  - name: jank_type
    label: 掉帧类型
    type: string
  - name: vsync_missed
    label: 跳帧数
    type: number
  - name: present_interval_ms
    label: 呈现间隔(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: jank_responsibility
    label: 责任归属
    type: string
  - name: frame_timeline_coverage_status
    label: FrameTimeline 覆盖状态
    type: string
    hidden: true
  - name: frame_timeline_to_buffer_tx_ratio
    label: FrameTimeline/BufferTX 帧数比
    type: number
    hidden: true
  - name: evidence_scope
    label: 根因证据范围
    type: string
    hidden: true
  - name: root_cause_eligible_frame_count
    label: 可分析掉帧
    type: number
    format: compact
    hidden: true
  - name: root_cause_analyzed_frame_count
    label: 已分析掉帧
    type: number
    format: compact
    hidden: true
  - name: root_cause_coverage_ratio
    label: 根因分析覆盖率
    type: percentage
    format: percentage
    hidden: true
  - name: root_cause_sample_limit_per_session
    label: 每 Session 采样上限
    type: number
    format: compact
    hidden: true
  - name: root_cause_analysis_scope
    label: 根因分析范围
    type: string
    hidden: true
  - name: reason_code
    label: 根因分类
    type: string
  - name: primary_cause
    label: 主要原因
    type: string
  - name: confidence
    label: 置信度
    type: string
  - name: top_slice_name
    label: 关键操作
    type: string
  - name: top_slice_ms
    label: 操作耗时
    type: duration
    format: duration_ms
  - name: main_q1_pct
    label: Q1 大核运行%
    type: percentage
    format: percentage
    hidden: true
  - name: main_q2_pct
    label: Q2 小核运行%
    type: percentage
    format: percentage
    hidden: true
  - name: main_q3_pct
    label: Q3 调度等待%
    type: percentage
    format: percentage
    hidden: true
  - name: main_q4a_pct
    label: Q4a 不可中断等待%
    type: percentage
    format: percentage
    hidden: true
  - name: main_q4b_pct
    label: Q4b 可中断睡眠/同步等待%
    type: percentage
    format: percentage
    hidden: true
  - name: render_q1_pct
    label: RT Q1 大核%
    type: percentage
    format: percentage
    hidden: true
  - name: render_q2_pct
    label: RT Q2 小核%
    type: percentage
    format: percentage
    hidden: true
  - name: render_q3_pct
    label: RT Q3 调度%
    type: percentage
    format: percentage
    hidden: true
  - name: render_q4a_pct
    label: RT Q4a 不可中断等待%
    type: percentage
    format: percentage
    hidden: true
  - name: render_q4b_pct
    label: RT Q4b 可中断睡眠/同步等待%
    type: percentage
    format: percentage
    hidden: true
  - name: big_avg_freq_mhz
    label: 大核均频
    type: number
    hidden: true
  - name: big_max_freq_mhz
    label: 大核峰频
    type: number
    hidden: true
  - name: ramp_ms
    label: 升频延迟
    type: duration
    format: duration_ms
    hidden: true
  - name: top_slice_little_pct
    label: 小核占比%
    type: percentage
    format: percentage
    hidden: true
  - name: top_slice_big_pct
    label: 大核占比%
    type: percentage
    format: percentage
    hidden: true
  - name: top_slice_runnable_pct
    label: Runnable占比%
    type: percentage
    format: percentage
    hidden: true
  - name: gpu_fence_ms
    label: GPU Fence最长
    type: duration
    format: duration_ms
    hidden: true
  - name: gpu_fence_total_ms
    label: GPU Fence总计
    type: duration
    format: duration_ms
    hidden: true
  - name: shader_count
    label: Shader编译次数
    type: number
    hidden: true
  - name: shader_ms
    label: Shader编译耗时
    type: duration
    format: duration_ms
    hidden: true
  - name: binder_overlap_ms
    label: Binder重叠
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
  - name: lock_contention_ms
    label: Monitor锁竞争重叠
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
  - name: render_sync_wait_ms
    label: 主线程等待RenderThread
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
  - name: render_sync_rt_work_ms
    label: RenderThread同步阶段工作
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
  - name: gc_overlap_ms
    label: GC重叠
    type: duration
    format: duration_ms
    hidden: true
  - name: gc_count
    label: GC次数
    type: number
    hidden: true
  - name: frame_budget_ms
    label: 帧预算
    type: duration
    format: duration_ms
    hidden: true
  - name: vsync_source
    label: 帧预算来源
    type: string
    hidden: true
  - name: device_peak_freq_mhz
    label: 设备峰值频率
    type: number
    hidden: true
  - name: file_io_overlap_ms
    label: 文件IO重叠
    type: duration
    format: duration_ms
    hidden: true
  - name: input_event_count
    label: Input事件数
    type: number
    hidden: true
  - name: input_move_count
    label: MOVE事件数
    type: number
    hidden: true
  - name: input_handling_ms
    label: 最慢Input处理
    type: duration
    format: duration_ms
    hidden: true
  - name: input_handling_total_ms
    label: Input处理总计
    type: duration
    format: duration_ms
    hidden: true
  - name: input_dispatch_ms
    label: 最慢Input分发
    type: duration
    format: duration_ms
    hidden: true
  - name: input_e2e_ms
    label: 最慢Input→Present
    type: duration
    format: duration_ms
    hidden: true
  - name: input_slice_ms
    label: Input阶段重叠
    type: duration
    format: duration_ms
    hidden: true
  - name: input_stage
    label: 主要Input阶段
    type: string
    hidden: true
  - name: input_speculative_events
    label: 推测帧关联事件
    type: number
    hidden: true
  - name: cpu_freq_clusters_json
    label: CPU频率详情
    type: string
    hidden: true
  - name: freq_timeline_json
    label: 频率变化时间线
    type: string
    hidden: true
  - name: main_slices_json
    label: 主线程耗时操作
    type: string
    hidden: true
  - name: render_slices_json
    label: 渲染线程耗时操作
    type: string
    hidden: true
  - name: binder_calls_json
    label: Binder调用
    type: string
    hidden: true
  - name: gc_events_json
    label: GC事件
    type: string
    hidden: true
  - name: lock_contention_json
    label: 锁竞争
    type: string
    hidden: true
  - name: input_events_json
    label: Input事件详情
    type: string
    hidden: true
  - name: input_slices_json
    label: Input阶段Slice
    type: string
    hidden: true
process_scope:
  role: target
  binding: effective_target_processes
  context_fields:
    global_context:
    - big_avg_freq_mhz
    - big_max_freq_mhz
    - ramp_ms
    - frame_budget_ms
    - vsync_source
    - device_peak_freq_mhz
    - cpu_freq_clusters_json
    - freq_timeline_json
    peer_context:
    - binder_calls_json
save_as: batch_root_cause
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && environment?.data?.[0]?.has_data === 1 && ((perf_summary?.data?.[0]?.janky_frames
  || 0) > 0 || (jank_stats?.data?.[0]?.real_jank_count || 0) > 0)
```
### 全局上下文标志

- ID: `global_context_flags`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/global_context_flags.sql`](../sql/scrolling_analysis/global_context_flags.sql)

```yaml
id: global_context_flags
type: atomic
optional: true
display:
  level: hidden
sql_fragments:
- fragments/effective_target_processes.sql
process_scope:
  role: target
  binding: effective_target_processes
  context_fields:
    global_context:
    - video_during_scroll
    - video_slice_count
    - trace_peak_freq_mhz
    - tail_min_freq_mhz
    - thermal_trending
    peer_context:
    - non_app_big_core_pct
    - background_cpu_heavy
save_as: global_context
```
### 滑动过程四象限分布

- ID: `session_quadrant_summary`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/session_quadrant_summary.sql`](../sql/scrolling_analysis/session_quadrant_summary.sql)

```yaml
id: session_quadrant_summary
type: atomic
optional: true
display: false
sql_fragments:
- fragments/effective_target_processes.sql
process_scope:
  role: target
  binding: effective_target_processes
save_as: session_quadrant
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && (perf_summary?.data?.[0]?.total_frames || 0) > 0
```
### 滑动过程 CPU 频率

- ID: `session_cpu_freq`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/session_cpu_freq.sql`](../sql/scrolling_analysis/session_cpu_freq.sql)

```yaml
id: session_cpu_freq
type: atomic
optional: true
display: false
process_scope:
  role: global_context
save_as: session_freq
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && (perf_summary?.data?.[0]?.total_frames || 0) > 0
```
### 关键线程大小核分布

- ID: `session_thread_core_affinity`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/session_thread_core_affinity.sql`](../sql/scrolling_analysis/session_thread_core_affinity.sql)

```yaml
id: session_thread_core_affinity
type: atomic
optional: true
display: false
sql_fragments:
- fragments/effective_target_processes.sql
process_scope:
  role: target
  binding: effective_target_processes
save_as: session_core_affinity
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && (perf_summary?.data?.[0]?.total_frames || 0) > 0
```
### 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/root_cause_classification.sql`](../sql/scrolling_analysis/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
optional: true
synthesize:
  role: conclusion
  fields:
  - key: problem_category
    label: 问题类别
  - key: problem_component
    label: 问题组件
  - key: confidence
    label: 置信度
    format: '{{value}}%'
  insights:
  - template: 根因分类：{{problem_category}} - {{problem_component}}
display:
  level: summary
  layer: overview
  title: 🎯 分析结论
  columns:
  - name: problem_category
    label: 问题类别
    type: enum
  - name: problem_component
    label: 问题组件
    type: string
  - name: confidence
    label: 置信度
    type: percentage
    format: percentage
  - name: root_cause_summary
    label: 根因总结
    type: string
  - name: suggestion
    label: 优化建议
    type: string
sql_fragments:
- fragments/effective_target_processes.sql
process_scope:
  role: target
  binding: effective_target_processes
save_as: conclusion
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && (perf_summary?.data?.[0]?.total_frames || 0) > 0 && enable_frame_details
  === true
```
### 数据源不可用提示

- ID: `fallback_no_frame_timeline`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/fallback_no_frame_timeline.sql`](../sql/scrolling_analysis/fallback_no_frame_timeline.sql)

```yaml
id: fallback_no_frame_timeline
type: atomic
condition: frame_timeline.data[0]?.has_frame_timeline === 0 || (environment?.data?.[0]?.has_data !== 1 && (perf_summary?.data?.[0]?.total_frames
  || 0) === 0)
display:
  level: summary
  layer: overview
  title: 滑动分析 - 数据源缺失
  columns:
  - name: status
    label: 状态
    type: string
  - name: missing_table
    label: 缺失数据表
    type: string
  - name: suggestion
    label: 建议
    type: string
process_scope:
  role: identity_metadata
  exact_unavailable: No FrameTimeline evidence is available for this UPID; BufferTX names cannot establish exact frame rate
    or jank.
save_as: fallback_info
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- overview
- list
conclusion:
  category: $conclusion.problem_category
  component: $conclusion.problem_component
  confidence: $conclusion.confidence
  summary: $conclusion.root_cause_summary
  evidence: $conclusion.evidence
  suggestion: $conclusion.suggestion
```
