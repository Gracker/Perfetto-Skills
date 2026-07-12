GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/scrolling_analysis.skill.yaml
Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# 滑动性能分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: scrolling_analysis
version: '2.1'
type: composite
tier: S
```

## Metadata

```yaml
display_name: 滑动性能分析
description: 基于 Perfetto FrameTimeline 与 android.input 的滑动分析，分层展示：概览 → 区间 → 帧详情
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
- android.binder
- android.garbage_collection
- android.monitor_contention
```

## Inputs

```yaml
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
save_as: frame_timeline
```
### Vsync 配置

- ID: `vsync_config`
- Type: `atomic`
- SQL: [`../sql/scrolling_analysis/vsync_config.sql`](../sql/scrolling_analysis/vsync_config.sql)

```yaml
id: vsync_config
type: atomic
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
save_as: environment
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
save_as: perf_summary
condition: frame_timeline.data[0]?.has_frame_timeline === 1 && environment.data[0]?.has_data === 1
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
synthesize:
  role: list
  groupBy:
  - field: jank_responsibility
    title: 责任归属分布
  - field: jank_type
    title: 掉帧类型分布
display: false
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
synthesize:
  role: list
  groupBy:
  - field: jank_responsibility
    title: 责任归属分布
  - field: reason_code
    title: 根因分类分布
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
    label: Q4b 锁/等待%
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
    label: RT Q4b 锁/等待%
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
condition: frame_timeline.data[0]?.has_frame_timeline === 0
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
