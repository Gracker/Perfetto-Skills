GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/startup_analysis.skill.yaml
Source SHA-256: 96b682a4206afafddcfb6e63c60e842921381a674744f413881a609e862ef41b
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 应用启动分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_analysis
version: '1.0'
type: composite
category: app_lifecycle
tier: S
```

## Metadata

```yaml
display_name: 应用启动分析
description: 全方位的应用启动性能分析
icon: rocket
tags:
- startup
- app
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 启动
  - 冷启动
  - 热启动
  - 温启动
  - 启动时间
  - 启动慢
  - 启动优化
  en:
  - startup
  - launch
  - cold start
  - warm start
  - hot start
  - app launch
patterns:
- .*启动.*时间.*
- .*启动.*慢.*
- .*launch.*
```

## Prerequisites

```yaml
modules:
- android.startup.startups
- android.startup.time_to_display
- android.startup.startup_breakdowns
- android.binder
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选，不填则分析所有启动事件）
- name: startup_id
  type: integer
  required: false
  description: 指定启动事件 ID（可选）
- name: startup_type
  type: string
  required: false
  description: 启动类型过滤（cold/warm/hot，可选）
- name: start_ts
  type: timestamp
  required: false
  description: 启动区间开始时间戳（ns，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 启动区间结束时间戳（ns，可选）
- name: analysis_mode
  type: string
  required: false
  description: 分析模式：full（默认）或 overview（仅启动事件定位）
- name: enable_startup_details
  type: boolean
  required: false
  description: 是否执行逐个启动事件详情分析（默认 true）
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

### 获取启动事件

- ID: `get_startups`
- Type: `skill`

```yaml
id: get_startups
type: skill
skill: startup_events_in_range
synthesize:
  role: overview
  fields:
  - key: startup_type
    label: 启动类型
  - key: dur_ms
    label: 启动耗时
    format: '{{value}} ms'
  - key: ttid_ms
    label: TTID
    format: '{{value}} ms'
  - key: rating
    label: 评级
  insights:
  - condition: dur_ms > 2000 && startup_type === 'cold'
    template: 冷启动耗时 {{dur_ms}}ms，超过 2s 需要优化
  - condition: dur_ms > 1000 && dur_ms <= 2000 && startup_type === 'cold'
    template: 冷启动耗时 {{dur_ms}}ms，超过 1s 建议优化
  - condition: dur_ms > 1000 && startup_type === 'warm'
    template: 温启动耗时 {{dur_ms}}ms，超过 1s 建议优化
display:
  level: key
  layer: overview
  title: 检测到的启动事件
  columns:
  - name: startup_id
    label: 启动 ID
    type: number
  - name: package
    label: 包名
    type: string
  - name: type_display
    label: 启动类型
    type: string
  - name: startup_type
    label: 修正后类型
    type: string
    hidden: true
  - name: original_type
    label: 原始类型
    type: string
    hidden: true
  - name: type_reclassified
    label: 类型已修正
    type: number
    hidden: true
  - name: type_confidence
    label: 类型置信度
    type: string
    hidden: true
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
  - name: start_ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: end_ts
    label: 结束时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur_ns
    label: 耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: ttid_ms
    label: TTID
    type: duration
    format: duration_ms
    unit: ms
  - name: ttfd_ms
    label: TTFD
    type: duration
    format: duration_ms
    unit: ms
  - name: rating
    label: 评级
    type: string
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: startups
on_empty: 未检测到启动事件。请确认 Trace 包含应用启动数据。
```
### 启动数据质量门禁

- ID: `startup_quality`
- Type: `atomic`
- SQL: [`../sql/startup_analysis/startup_quality.sql`](../sql/startup_analysis/startup_quality.sql)

```yaml
id: startup_quality
type: atomic
display:
  level: key
  layer: overview
  title: 启动数据质量
  columns:
  - name: sample_count
    label: 样本数
    type: number
  - name: blocker_count
    label: 阻断问题
    type: number
  - name: warning_count
    label: 告警问题
    type: number
  - name: quality_status
    label: 门禁状态
    type: string
  - name: issue_codes
    label: 问题编码
    type: string
  - name: quality_summary
    label: 说明
    type: string
save_as: startup_quality
condition: startups.data.length > 0
```
### 启动延迟归因

- ID: `startup_breakdown`
- Type: `skill`

```yaml
id: startup_breakdown
type: skill
skill: startup_breakdown_in_range
synthesize:
  role: list
  groupBy:
  - field: category
    title: 延迟类别分布
  fields:
  - key: reason
    label: 延迟原因
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms ({{percent}}%)'
display:
  level: key
  layer: overview
  title: 启动延迟归因分析
  columns:
  - name: reason
    label: 延迟原因
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: percent
    label: 占比
    type: percentage
    format: percentage
  - name: category
    label: 类别
    type: string
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  top_k: 15
save_as: breakdown
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
### 主线程关键操作

- ID: `main_thread_slices`
- Type: `skill`

```yaml
id: main_thread_slices
type: skill
skill: startup_main_thread_slices_in_range
synthesize:
  role: list
  groupBy:
  - field: startup_type
    title: 按启动类型分布
  fields:
  - key: slice_name
    label: 操作名称
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms'
  - key: percent_of_startup
    label: 占比
    format: '{{value}}%'
display:
  level: key
  layer: overview
  title: 主线程耗时操作 Top15
  columns:
  - name: slice_name
    label: 操作名称
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: percent_of_startup
    label: 启动占比
    type: percentage
    format: percentage
  - name: startup_type
    label: 启动类型
    type: string
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  min_dur_ns: 1000000
  top_k: 15
save_as: main_thread_slices
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
### 主线程文件 IO

- ID: `main_thread_file_io`
- Type: `skill`

```yaml
id: main_thread_file_io
type: skill
skill: startup_main_thread_file_io_in_range
synthesize:
  role: list
  groupBy:
  - field: startup_type
    title: 按启动类型分布
  fields:
  - key: io_slice
    label: IO 操作
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms'
  - key: percent_of_startup
    label: 占比
    format: '{{value}}%'
display:
  level: key
  layer: overview
  title: 主线程文件 IO Top15
  columns:
  - name: io_slice
    label: IO 操作
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: percent_of_startup
    label: 启动占比
    type: percentage
    format: percentage
  - name: startup_type
    label: 启动类型
    type: string
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  min_dur_ns: 500000
  top_k: 15
save_as: main_thread_file_io
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
### 启动期间 Binder 调用

- ID: `startup_binder`
- Type: `skill`

```yaml
id: startup_binder
type: skill
skill: startup_binder_in_range
synthesize:
  role: list
  groupBy:
  - field: server_process
    title: 按服务进程分布
  fields:
  - key: aidl_name
    label: AIDL 方法
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms'
  - key: call_count
    label: 调用次数
  insights:
  - condition: percent_of_startup > 20
    template: Binder 调用占启动时间 {{percent_of_startup}}%，需优化
display:
  level: key
  layer: overview
  title: 启动期间 Binder 调用
  columns:
  - name: server_process
    label: 服务进程
    type: string
  - name: aidl_name
    label: AIDL 方法
    type: string
  - name: call_count
    label: 调用次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: main_thread_calls
    label: 主线程调用
    type: number
  - name: percent_of_startup
    label: 启动占比
    type: percentage
    format: percentage
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  top_k: 15
save_as: startup_binder
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
### 主线程同步 Binder 调用

- ID: `main_thread_sync_binder`
- Type: `skill`

```yaml
id: main_thread_sync_binder
type: skill
skill: startup_main_thread_sync_binder_in_range
display:
  level: key
  layer: overview
  title: 主线程同步 Binder 调用
  columns:
  - name: server_process
    label: 服务进程
    type: string
  - name: aidl_name
    label: AIDL 方法
    type: string
  - name: call_count
    label: 调用次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: percent_of_startup
    label: 启动占比
    type: percentage
    format: percentage
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  top_k: 15
save_as: main_sync_binder
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
### 主线程 Binder 阻塞

- ID: `main_thread_binder_blocking`
- Type: `skill`

```yaml
id: main_thread_binder_blocking
type: skill
skill: startup_main_thread_binder_blocking_in_range
display:
  level: detail
  layer: list
  title: 主线程 Binder 阻塞分析
  columns:
  - name: server_process
    label: 服务进程
    type: string
  - name: aidl_name
    label: AIDL 方法
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: state
    label: 阻塞状态
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
    format: code
  - name: ts_str
    label: 时间戳
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: severity
    label: 严重程度
    type: enum
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  min_dur_ns: 5000000
  top_k: 20
save_as: main_binder_blocking
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
### 主线程状态分析

- ID: `main_thread_state_during_startup`
- Type: `skill`

```yaml
id: main_thread_state_during_startup
type: skill
skill: startup_main_thread_states_in_range
display:
  level: key
  layer: overview
  title: 启动期间主线程状态
  columns:
  - name: state
    label: 状态
    type: string
  - name: state_desc
    label: 状态说明
    type: string
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: percent
    label: 占比
    type: percentage
    format: percentage
  - name: count
    label: 次数
    type: number
    format: compact
  - name: blocked_functions
    label: 阻塞函数
    type: string
    format: truncate
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: main_thread_states
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
### 类加载分析

- ID: `class_loading`
- Type: `skill`

```yaml
id: class_loading
type: skill
skill: startup_class_loading_in_range
display:
  level: detail
  layer: list
  title: 启动期间类加载
  columns:
  - name: slice_name
    label: 类名
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: percent_of_startup
    label: 启动占比
    type: percentage
    format: percentage
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  top_k: 10
save_as: class_loading
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
### GC 影响分析

- ID: `gc_during_startup`
- Type: `skill`

```yaml
id: gc_during_startup
type: skill
skill: startup_gc_in_range
display:
  level: detail
  layer: list
  title: 启动期间 GC
  columns:
  - name: gc_type
    label: GC 类型
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: is_main_thread
    label: 主线程
    type: boolean
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: percent_of_startup
    label: 启动占比
    type: percentage
    format: percentage
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  top_k: 10
save_as: gc_during_startup
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
### 调度延迟分析

- ID: `sched_latency_during_startup`
- Type: `skill`

```yaml
id: sched_latency_during_startup
type: skill
skill: startup_sched_latency_in_range
display:
  level: detail
  layer: list
  title: 启动期间调度延迟
  columns:
  - name: state
    label: 状态
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_wait_ms
    label: 总等待
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_wait_ms
    label: 平均等待
    type: duration
    format: duration_ms
    unit: ms
  - name: max_wait_ms
    label: 最大等待
    type: duration
    format: duration_ms
    unit: ms
  - name: severe_delays
    label: 严重延迟次数
    type: number
params:
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: sched_latency
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
### 启动事件详细分析

- ID: `analyze_startups`
- Type: `iterator`

```yaml
id: analyze_startups
type: iterator
synthesize:
  role: clusters
  clusterBy: startup_type
display:
  level: key
  layer: deep
  title: 启动事件详细分析
source: startups
item_skill: startup_detail
item_params:
  startup_id: startup_id
  start_ts: start_ts
  end_ts: end_ts
  dur_ms: dur_ms
  package: package
  startup_type: startup_type
  original_type: original_type
  ttid_ms: ttid_ms
  ttfd_ms: ttfd_ms
  perfetto_start: perfetto_start
  perfetto_end: perfetto_end
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0) && ${enable_startup_details|true}
```
### 启动诊断

- ID: `startup_diagnosis`
- Type: `diagnostic`

```yaml
id: startup_diagnosis
type: diagnostic
synthesize:
  role: conclusion
  fields:
  - key: diagnosis
    label: 诊断结论
  - key: severity
    label: 严重程度
  - key: confidence
    label: 置信度
  insights:
  - template: 启动性能诊断：{{diagnosis}}
display:
  level: key
  layer: overview
  title: 问题诊断
inputs:
- startups
- startup_quality
- breakdown
- main_thread_slices
- main_thread_file_io
- startup_binder
- main_sync_binder
- main_binder_blocking
- main_thread_states
- class_loading
- gc_during_startup
- sched_latency
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview'
rules:
- condition: ((startup_quality?.data?.[0]?.blocker_count) || 0) > 0
  severity: critical
  diagnosis: 启动数据质量存在阻断问题（${startup_quality?.data?.[0]?.issue_codes || 'unknown'}），深度分析已跳过
  confidence: high
  suggestions:
  - 优先核对 dur_ms/start_ts/end_ts 的单位与换算逻辑，统一为 ms 展示
  - 检查 TTID/TTFD 字段来源和单位，确认没有误用 us/ns
  - 修复数据口径后重新执行启动分析
- condition: (startups?.data?.[0]?.ttid_ms || 0) > (startups?.data?.[0]?.dur_ms || 0) + 50
  severity: warning
  diagnosis: TTID (${startups?.data?.[0]?.ttid_ms}ms) 超出启动总时长 (${startups?.data?.[0]?.dur_ms}ms)，首帧渲染可能在 Perfetto 认定的启动结束后才完成
  confidence: medium
  suggestions:
  - 可能原因：Activity.setContentView 后仍有异步加载导致首帧延迟，或 RenderThread/SurfaceFlinger 合成排队
  - 检查启动区间结束后是否有较长的 Choreographer#doFrame 或 DrawFrame
  - 如果 TTID 代表真实首帧时间，优化方向应以 TTID 而非 dur 为目标
  - 建议在 Perfetto UI 中检查 startup 结束时间戳附近的帧渲染情况
- condition: ((startup_quality?.data?.[0]?.warning_count) || 0) > 0 && !((startup_quality?.data?.[0]?.issue_codes || '').includes('R008_TTID_GT_DUR')
    && (startup_quality?.data?.[0]?.warning_count || 0) === 1)
  severity: info
  diagnosis: 启动数据存在告警项（${startup_quality?.data?.[0]?.issue_codes || 'none'}），结论需结合原始 Trace 复核
  confidence: medium
  suggestions:
  - 重点复核 TTID/TTFD 与启动总时长关系是否合理
  - 保留本次结论作为线索，不直接作为最终定论
- condition: (startups?.data?.[0]?.type_reclassified || 0) === 1
  severity: info
  diagnosis: 启动类型已从 ${startups?.data?.[0]?.original_type} 修正为 ${startups?.data?.[0]?.startup_type}。判定依据：bindApplication 存在→cold，仅
    performCreate 存在→warm，均不存在→保持原始分类。评级已按修正后类型重新计算。
  confidence: high
  suggestions:
  - Perfetto 的 startup_type 来自框架层 atrace 标记，在某些场景下可能误报
  - bindApplication 是进程新建（冷启动）的可靠信号，performCreate 是 Activity 重建（温启动）的可靠信号
- condition: ((startups?.data?.[0]?.dur_ms) || 0) > 2000 && startups?.data?.[0]?.startup_type === 'cold'
  severity: critical
  diagnosis: 冷启动时间过长 (${startups?.data?.[0]?.dur_ms}ms)
  confidence: high
  suggestions:
  - 检查 Application.onCreate() 中的初始化逻辑
  - 使用 App Startup 库延迟初始化
  - 将耗时操作移到后台线程
- condition: ((startups?.data?.[0]?.dur_ms) || 0) > 1000 && ((startups?.data?.[0]?.dur_ms) || 0) <= 2000 && startups?.data?.[0]?.startup_type
    === 'cold'
  severity: warning
  diagnosis: 冷启动时间偏长 (${startups?.data?.[0]?.dur_ms}ms)，建议优化
  confidence: high
  suggestions:
  - 检查 Application.onCreate() 和 Activity.onCreate() 中的耗时操作
  - 将非关键初始化延迟到首帧之后
  - 使用 Baseline Profile 加速类加载和 JIT
- condition: ((startups?.data?.[0]?.dur_ms) || 0) > 1000 && startups?.data?.[0]?.startup_type === 'warm'
  severity: critical
  diagnosis: 温启动时间严重偏长 (${startups?.data?.[0]?.dur_ms}ms)，接近甚至超过正常冷启动水平
  confidence: high
  suggestions:
  - 温启动进程已存在，不应有 Application.onCreate 开销
  - 检查 Activity.onCreate() 和 onStart()/onResume() 中是否重复执行初始化
  - 将 View 绑定、数据加载等操作移到后台线程
- condition: ((startups?.data?.[0]?.dur_ms) || 0) > 500 && ((startups?.data?.[0]?.dur_ms) || 0) <= 1000 && startups?.data?.[0]?.startup_type
    === 'warm'
  severity: warning
  diagnosis: 温启动时间偏长 (${startups?.data?.[0]?.dur_ms}ms)，建议优化
  confidence: high
  suggestions:
  - 检查 Activity.onCreate()/onResume() 中的耗时操作
  - 使用 ViewStub 延迟加载非首屏视图
  - 减少 Activity 重建时的数据库/网络查询
- condition: ((startups?.data?.[0]?.dur_ms) || 0) > 500 && startups?.data?.[0]?.startup_type === 'hot'
  severity: critical
  diagnosis: 热启动时间严重偏长 (${startups?.data?.[0]?.dur_ms}ms)，热启动应在 200ms 内完成
  confidence: high
  suggestions:
  - 热启动只需 onResume() → 首帧，检查是否有不必要的数据重载
  - 排查 onResume() 中的同步 Binder 或 IO 阻塞
- condition: ((startups?.data?.[0]?.dur_ms) || 0) > 200 && ((startups?.data?.[0]?.dur_ms) || 0) <= 500 && startups?.data?.[0]?.startup_type
    === 'hot'
  severity: warning
  diagnosis: 热启动时间偏长 (${startups?.data?.[0]?.dur_ms}ms)，建议优化
  confidence: high
  suggestions:
  - 检查 onResume() 中是否有不必要的数据刷新或视图重建
  - 减少热启动路径上的同步调用
- condition: (startup_binder?.data?.length || 0) > 0 && ((startup_binder.data[0]?.percent_of_startup) || 0) > 20 && ((startup_binder.data[0]?.main_thread_calls
    || 0) > 0) && ((((main_sync_binder?.data?.[0]?.percent_of_startup) || 0) > 5) || (((main_binder_blocking?.data?.[0]?.dur_ms)
    || 0) > 8) || (((main_thread_states?.data?.find(s => s.state === 'D')?.percent) || 0) > 5) || (((main_thread_states?.data?.find(s
    => s.state === 'S')?.percent) || 0) > 20))
  severity: warning
  diagnosis: Binder 调用占启动时间 ${startup_binder?.data?.[0]?.percent_of_startup}%（含主线程调用）
  confidence: high
  suggestions:
  - 减少启动期间的 IPC 调用
  - 将非必要的服务调用延迟到启动后
  - 使用异步 Binder 调用
- condition: (main_sync_binder?.data?.length || 0) > 0 && ((main_sync_binder.data[0]?.percent_of_startup) || 0) > 8 && ((((main_binder_blocking?.data?.[0]?.dur_ms)
    || 0) > 16) || (((main_thread_states?.data?.find(s => s.state === 'D')?.percent) || 0) > 5) || (((main_thread_states?.data?.find(s
    => s.state === 'S')?.percent) || 0) > 20))
  severity: warning
  diagnosis: 主线程同步 Binder 占启动时间 ${main_sync_binder?.data?.[0]?.percent_of_startup}% 且主线程存在阻塞态证据
  confidence: high
  suggestions:
  - 优先将同步 Binder 调用迁移到后台线程
  - 首屏前只保留必要 IPC，其余延后到首帧后
- condition: (main_thread_file_io?.data?.length || 0) > 0 && (((main_thread_file_io.data[0]?.percent_of_startup) || 0) > 5
    || ((main_thread_file_io.data[0]?.total_dur_ms) || 0) > 50) && ((((main_thread_states?.data?.find(s => s.state === 'D')?.percent)
    || 0) > 5) || (((main_thread_states?.data?.find(s => s.state === 'S')?.percent) || 0) > 20))
  severity: warning
  diagnosis: 主线程文件 IO 占比较高（${main_thread_file_io?.data?.[0]?.percent_of_startup}%）且主线程阻塞态占比偏高
  confidence: high
  suggestions:
  - 将文件读取与数据库初始化前移到预热阶段或改为异步
  - 减少启动阶段小文件随机 IO，合并为批量顺序读取
- condition: (main_thread_states?.data?.length || 0) > 0 && ((main_thread_states.data.find(s => s.state === 'Running')?.percent)
    || 0) < 50 && ((((main_thread_states.data.find(s => s.state === 'R')?.percent) || 0) + ((main_thread_states.data.find(s
    => s.state === 'R+')?.percent) || 0)) > 20 || ((((main_thread_states.data.find(s => s.state === 'D')?.percent) || 0) +
    ((main_thread_states.data.find(s => s.state === 'S')?.percent) || 0)) > 30) || ((((sched_latency?.data?.find(s => s.state
    === 'R')?.severe_delays) || 0) + ((sched_latency?.data?.find(s => s.state === 'R+')?.severe_delays) || 0)) > 3))
  severity: warning
  diagnosis: 主线程 Running 比例偏低
  confidence: medium
  suggestions:
  - 分析阻塞原因：IO 等待、锁竞争、调度延迟
  - 将阻塞操作移到后台线程
- condition: (gc_during_startup?.data?.length || 0) > 0 && ((gc_during_startup.data.find(g => g.is_main_thread === 1)?.percent_of_startup)
    || 0) > 3
  severity: warning
  diagnosis: 主线程 GC 占启动时间 ${gc_during_startup?.data?.find(g => g.is_main_thread === 1)?.percent_of_startup}%
  confidence: medium
  suggestions:
  - 减少启动期间的对象分配
  - 避免在启动时创建大量临时对象
- condition: (sched_latency?.data?.length || 0) > 0 && ((((sched_latency.data.find(s => s.state === 'R')?.severe_delays) ||
    0) + ((sched_latency.data.find(s => s.state === 'R+')?.severe_delays) || 0)) > 3) && (((sched_latency.data.find(s => s.state
    === 'R')?.max_wait_ms) || 0) > 8 || ((sched_latency.data.find(s => s.state === 'R+')?.max_wait_ms) || 0) > 8)
  severity: warning
  diagnosis: 主线程调度延迟偏高（>8ms 严重等待次数 ${(sched_latency?.data?.find(s => s.state === 'R')?.severe_delays || 0) + (sched_latency?.data?.find(s
    => s.state === 'R+')?.severe_delays || 0)}）
  confidence: medium
  suggestions:
  - 降低启动阶段后台并发，避免与主线程争抢 CPU
  - 检查系统级负载和高优先级抢占线程
- condition: (breakdown?.data?.length || 0) > 0 && ((breakdown.data.find(b => b.category === 'ClassLoading')?.percent) ||
    0) > 15 && (class_loading?.data?.length || 0) > 0 && ((class_loading.data[0]?.percent_of_startup) || 0) > 5
  severity: info
  diagnosis: 类加载占比较高（breakdown ${breakdown?.data?.find(b => b.category === 'ClassLoading')?.percent}%）
  confidence: medium
  suggestions:
  - 使用 baseline profile 预编译热点类
  - 减少启动时加载的类数量
```
### 启动证据矩阵

- ID: `startup_evidence_matrix`
- Type: `atomic`
- SQL: [`../sql/startup_analysis/startup_evidence_matrix.sql`](../sql/startup_analysis/startup_evidence_matrix.sql)

```yaml
id: startup_evidence_matrix
type: atomic
display:
  level: key
  layer: overview
  title: 证据矩阵
  columns:
  - name: item
    label: 分析项
    type: string
  - name: primary_metric
    label: 主指标
    type: string
  - name: primary_value
    label: 主指标值
    type: number
  - name: primary_threshold
    label: 异常阈值
    type: string
  - name: corroborating_metric
    label: 佐证指标
    type: string
  - name: corroborating_value
    label: 佐证值
    type: number
  - name: corroborating_threshold
    label: 佐证阈值
    type: string
  - name: status
    label: 判定
    type: string
save_as: evidence_matrix
condition: startups.data.length > 0 && '${analysis_mode|full}' !== 'overview' && ((startup_quality?.data?.[0]?.blocker_count
  || 0) === 0)
```
## Output and evidence contract

```yaml
format: structured
```
