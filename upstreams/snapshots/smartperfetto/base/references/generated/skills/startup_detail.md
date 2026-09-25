GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/startup_detail.skill.yaml
Source SHA-256: 33481081237e74c06b4dc8d1d96123519db58062a3214483d83a5ab46c43d287
Source commit: 459063305709d69ae0a322371bba3f506c41c62c
# 启动详情分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_detail
version: '2.0'
type: composite
category: app_lifecycle
tier: S
```

## Metadata

```yaml
display_name: 启动详情分析
description: 深入分析单个启动过程的性能瓶颈
icon: search
tags:
- startup
- detail
- composite
```

## Prerequisites

```yaml
required_tables:
- android_startups
modules:
- android.startup.startups
- android.binder
- linux.cpu.frequency
```

## Inputs

```yaml
- name: startup_id
  type: integer
  required: true
  description: 启动事件 ID
- name: start_ts
  type: timestamp
  required: true
  description: 启动开始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 启动结束时间戳(ns)
- name: dur_ms
  type: number
  required: true
  description: 启动耗时(ms)
- name: package
  type: string
  required: true
  description: 应用包名
- name: startup_type
  type: string
  required: true
  description: 启动类型 (cold/warm/hot)，已经过 bindApplication 存在性校验
- name: original_type
  type: string
  required: false
  description: Perfetto 原始报告的启动类型（校验前）
- name: ttid_ms
  type: number
  required: false
  description: TTID (ms)
- name: ttfd_ms
  type: number
  required: false
  description: TTFD (ms)
- name: perfetto_start
  type: timestamp
  required: false
  description: Perfetto 跳转开始时间
- name: perfetto_end
  type: timestamp
  required: false
  description: Perfetto 跳转结束时间
```

## Identity requirements

```yaml
policy: required
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
### 启动基本信息

- ID: `startup_info`
- Type: `atomic`
- SQL: [`../sql/startup_detail/startup_info.sql`](../sql/startup_detail/startup_info.sql)

```yaml
id: startup_info
type: atomic
display:
  level: key
  layer: deep
  title: '启动 #${startup_id} 详情'
  columns:
  - name: startup_id
    label: 启动 ID
    type: number
  - name: package
    label: 包名
    type: string
  - name: startup_type
    label: 启动类型
    type: string
  - name: type_display
    label: 类型展示
    type: string
  - name: dur_ms
    label: 启动耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: ttid_ms
    label: TTID(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: ttfd_ms
    label: TTFD(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: start_ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
  - name: end_ts
    label: 结束时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: perfetto_start
    label: Perfetto开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
  - name: perfetto_end
    label: Perfetto结束
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: rating
    label: 评级
    type: string
save_as: startup_basic
```
### 大小核占比分析

- ID: `cpu_core_analysis`
- Type: `atomic`
- SQL: [`../sql/startup_detail/cpu_core_analysis.sql`](../sql/startup_detail/cpu_core_analysis.sql)

```yaml
id: cpu_core_analysis
type: atomic
display:
  level: key
  layer: deep
  title: 大小核占比
  columns:
  - name: thread_type
    label: 线程类型
    type: string
  - name: big_core_ms
    label: 大核运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: little_core_ms
    label: 小核运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: total_running_ms
    label: 总运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: big_core_pct
    label: 大核占比(%)
    type: percentage
    format: percentage
  - name: little_core_pct
    label: 小核占比(%)
    type: percentage
    format: percentage
  - name: used_cpus
    label: 使用CPU
    type: string
  - name: classify_method
    label: 核判定来源
    type: string
  - name: unknown_core_ms
    label: 未知核类型运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: unknown_core_pct
    label: 未知核类型占比
    type: percentage
process_scope:
  role: target
  binding: effective_target_processes
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/system_sched_spans.sql
save_as: cpu_core
```
### CPU 频率分析

- ID: `cpu_freq_analysis`
- Type: `atomic`
- SQL: [`../sql/startup_detail/cpu_freq_analysis.sql`](../sql/startup_detail/cpu_freq_analysis.sql)

```yaml
id: cpu_freq_analysis
type: atomic
display:
  level: detail
  layer: deep
  title: CPU 频率
  columns:
  - name: core_type
    label: 核心类型
    type: string
  - name: avg_freq_mhz
    label: 平均频率(MHz)
    type: number
  - name: max_freq_mhz
    label: 最高频率(MHz)
    type: number
  - name: min_freq_mhz
    label: 最低频率(MHz)
    type: number
  - name: classify_method
    label: 核判定来源
    type: string
process_scope:
  role: target
  binding: effective_target_processes
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/system_sched_spans.sql
- fragments/system_cpu_frequency_spans.sql
save_as: cpu_freq
```
### 逐核频率与系统负载上下文

- ID: `per_cpu_system_context`
- Type: `atomic`
- SQL: [`../sql/startup_detail/per_cpu_system_context.sql`](../sql/startup_detail/per_cpu_system_context.sql)

```yaml
id: per_cpu_system_context
type: atomic
display:
  level: key
  layer: deep
  title: 逐核系统上下文（非目标因果归因）
  columns:
  - name: idle_ns
    label: Idle duration
    type: duration
    unit: ns
    hidden: true
  - name: idle_identity_unknown_ns
    label: Unknown idle identity duration
    type: duration
    unit: ns
    hidden: true
  - name: sched_evidence
    label: Scheduler coverage
    type: string
    hidden: true
  - name: ucpu
    label: ucpu
    type: number
    hidden: true
  - name: window_start_ts
    label: window_start_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_end_ts
    label: window_end_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: capacity
    label: capacity
    type: number
    hidden: true
  - name: cluster_id
    label: cluster_id
    type: number
    hidden: true
  - name: machine_id
    label: machine_id
    type: number
    hidden: true
  - name: frequency_evidence
    label: frequency_evidence
    type: string
    hidden: true
  - name: upid
    label: UPID
    type: number
  - name: utid
    label: 主线程 UTID
    type: number
  - name: cpu
    label: CPU
    type: number
  - name: core_type
    label: 核类型
    type: string
  - name: topology_source
    label: 拓扑来源
    type: string
  - name: avg_freq_mhz
    label: 窗口加权均频(MHz)
    type: number
  - name: min_freq_mhz
    label: 最低频率(MHz)
    type: number
  - name: max_freq_mhz
    label: 最高频率(MHz)
    type: number
  - name: freq_coverage_ms
    label: 频率覆盖(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: freq_coverage_pct
    label: 频率覆盖比例
    type: percentage
  - name: sched_coverage_ms
    label: 调度记录覆盖(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: system_busy_ms
    label: 系统非 idle 运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: system_busy_pct
    label: 系统忙碌/窗口
    type: percentage
  - name: target_main_running_ms
    label: 目标主线程运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: pid
    label: 目标 PID
    type: number
    hidden: true
  - name: tid
    label: 目标 TID
    type: number
    hidden: true
  - name: process_name
    label: 目标进程
    type: string
    hidden: true
  - name: evidence_scope
    label: 证据边界
    type: string
    hidden: true
process_scope:
  role: target
  binding: effective_target_processes
  context_fields:
    global_context:
    - cpu
    - ucpu
    - machine_id
    - capacity
    - cluster_id
    - core_type
    - topology_source
    - avg_freq_mhz
    - min_freq_mhz
    - max_freq_mhz
    - freq_coverage_ms
    - freq_coverage_pct
    - frequency_evidence
    - system_busy_ms
    - system_busy_pct
    - sched_coverage_ms
    - idle_ns
    - idle_identity_unknown_ns
    - sched_evidence
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/system_sched_spans.sql
- fragments/system_cpu_frequency_spans.sql
save_as: per_cpu_context
optional: true
```
### 目标线程抢占切换证据

- ID: `preemption`
- Type: `atomic`
- SQL: [`../sql/startup_detail/preemption.sql`](../sql/startup_detail/preemption.sql)

```yaml
id: preemption
type: atomic
process_scope:
  role: target
  binding: effective_target_processes
  context_fields:
    peer_context:
    - next_sched_id
    - next_utid
    - next_tid
    - next_upid
    - next_pid
    - next_thread_name
    - next_process_name
    - next_priority
    - next_is_idle
    - next_role
sql_fragments:
- fragments/effective_target_processes.sql
display:
  level: key
  layer: deep
  title: R+ 抢占切出与直接 CPU 交接
  columns:
  - name: next_is_idle
    label: Successor is idle
    type: number
    hidden: true
  - name: next_role
    label: Successor role
    type: string
  - name: utid
    label: 目标 UTID
    type: number
  - name: thread_name
    label: 目标线程
    type: string
  - name: cpu
    label: CPU
    type: number
  - name: switch_ts
    label: 实际切出时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: priority
    label: 切出片段 kernel priority
    type: number
  - name: next_process_name
    label: 交接进程
    type: string
  - name: next_thread_name
    label: 交接线程
    type: string
  - name: next_priority
    label: 交接片段 kernel priority
    type: number
  - name: observed_wait_ms
    label: 窗口内 R+ 等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: wait_evidence
    label: 等待证据
    type: string
  - name: handoff_evidence
    label: 交接证据
    type: string
  - name: sched_id
    label: 切出 sched ID
    type: number
    hidden: true
  - name: upid
    label: 目标 UPID
    type: number
    hidden: true
  - name: pid
    label: 目标 PID
    type: number
    hidden: true
  - name: tid
    label: 目标 TID
    type: number
    hidden: true
  - name: process_name
    label: 目标进程
    type: string
    hidden: true
  - name: ucpu
    label: 唯一 CPU ID
    type: number
    hidden: true
  - name: next_sched_id
    label: 交接 sched ID
    type: number
    hidden: true
  - name: next_utid
    label: 交接 UTID
    type: number
    hidden: true
  - name: next_tid
    label: 交接 TID
    type: number
    hidden: true
  - name: next_upid
    label: 交接 UPID
    type: number
    hidden: true
  - name: next_pid
    label: 交接 PID
    type: number
    hidden: true
  - name: wait_state_id
    label: R+ 状态 ID
    type: number
    hidden: true
  - name: scheduling_policy_evidence
    label: 调度策略证据
    type: string
    hidden: true
save_as: preemption_handoffs
optional: true
```
### CPU 频率阶段对比

- ID: `freq_rampup`
- Type: `skill`

```yaml
id: freq_rampup
type: skill
skill: startup_freq_rampup
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
  layer: deep
  title: CPU 频率阶段对比
  columns:
  - name: ucpu
    label: UCPU
    type: number
  - name: cpu
    label: CPU
    type: number
  - name: machine_id
    label: Machine ID
    type: number
  - name: early_avg_freq_mhz
    label: 初期均频(MHz)
    type: number
  - name: steady_avg_freq_mhz
    label: 后段均频(MHz)
    type: number
  - name: max_freq_mhz
    label: 观测峰值(MHz)
    type: number
  - name: early_covered_ns
    label: 初期覆盖时长
    type: duration
    unit: ns
  - name: early_window_ns
    label: 初期窗口时长
    type: duration
    unit: ns
  - name: steady_covered_ns
    label: 后段覆盖时长
    type: duration
    unit: ns
  - name: steady_window_ns
    label: 后段窗口时长
    type: duration
    unit: ns
  - name: rampup_pct
    label: 后段相对变化(%)
    type: percentage
    format: percentage
  - name: assessment
    label: 评估
    type: string
  - name: claim_boundary
    label: 证据边界
    type: string
save_as: freq_rampup
optional: true
```
### 四大象限分析

- ID: `quadrant_analysis`
- Type: `atomic`
- SQL: [`../sql/startup_detail/quadrant_analysis.sql`](../sql/startup_detail/quadrant_analysis.sql)

```yaml
id: quadrant_analysis
type: atomic
optional: true
display:
  level: key
  layer: deep
  title: 四大象限分析
  columns:
  - name: thread_type
    label: 线程类型
    type: string
  - name: q1_big_running_ms
    label: Q1大核运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: q2_little_running_ms
    label: Q2小核运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: q3_runnable_ms
    label: Q3可运行等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: q4a_uninterruptible_ms
    label: Q4a不可中断等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: q4b_sleeping_ms
    label: Q4b 睡眠等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: total_ms
    label: 总时长(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: q1_pct
    label: Q1占比(%)
    type: percentage
    format: percentage
  - name: q2_pct
    label: Q2占比(%)
    type: percentage
    format: percentage
  - name: q3_pct
    label: Q3占比(%)
    type: percentage
    format: percentage
  - name: q4a_pct
    label: Q4a占比(%)
    type: percentage
    format: percentage
  - name: q4b_pct
    label: Q4b占比(%)
    type: percentage
    format: percentage
  - name: classify_method
    label: 核判定来源
    type: string
  - name: unknown_running_ms
    label: 未知核类型运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: other_state_ms
    label: 其他观测状态(ms)
    type: duration
    format: duration_ms
    unit: ms
process_scope:
  role: target
  binding: effective_target_processes
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/system_sched_spans.sql
- fragments/system_thread_state_spans.sql
save_as: quadrant
```
### 摆核时序分析

- ID: `cpu_placement_timeline`
- Type: `skill`

```yaml
id: cpu_placement_timeline
type: skill
skill: startup_cpu_placement_timeline
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  bucket_ms: 50
display:
  level: detail
  layer: deep
  title: 主线程摆核时序（50ms 桶）
  columns:
  - name: upid
    label: upid
    type: number
    hidden: true
  - name: utid
    label: utid
    type: number
    hidden: true
  - name: window_start_ts
    label: window_start_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_end_ts
    label: window_end_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: unknown_core_ms
    label: unknown_core_ms
    type: duration
    unit: ms
    hidden: true
  - name: used_ucpus
    label: used_ucpus
    type: string
    hidden: true
  - name: sched_covered_ns
    label: sched_covered_ns
    type: duration
    unit: ns
    hidden: true
  - name: sched_evidence
    label: sched_evidence
    type: string
    hidden: true
  - name: bucket_offset_ms
    label: 偏移(ms)
    type: number
  - name: big_core_ms
    label: 大核(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: little_core_ms
    label: 小核(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: big_core_pct
    label: 大核占比
    type: percentage
    format: percentage
  - name: used_cpus
    label: CPU
    type: string
save_as: cpu_placement
optional: true
```
### 主线程耗时操作

- ID: `main_thread_slices`
- Type: `skill`

```yaml
id: main_thread_slices
type: skill
skill: main_thread_slices_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
  min_dur_ns: 1000000
  top_k: 10
display:
  level: key
  layer: deep
  show: false
  title: 主线程耗时操作 Top10
  columns:
  - name: slice_name
    label: 切片名
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: percent
    label: 区间占比
    type: percentage
    format: percentage
save_as: main_slices
```
### 主线程可操作热点

- ID: `actionable_main_thread_slices`
- Type: `atomic`
- SQL: [`../sql/startup_detail/actionable_main_thread_slices.sql`](../sql/startup_detail/actionable_main_thread_slices.sql)

```yaml
id: actionable_main_thread_slices
type: atomic
display:
  level: detail
  layer: deep
  title: 主线程可操作热点 Top5
  columns:
  - name: slice_name
    label: 切片名
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_ms
    label: 总耗时(wall)
    type: duration
    format: duration_ms
    unit: ms
  - name: self_ms
    label: 自身耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: percent
    label: 区间占比(wall)
    type: percentage
    format: percentage
  - name: self_percent
    label: 区间占比(self)
    type: percentage
    format: percentage
  - name: is_framework_wrapper
    label: 框架包裹切片
    type: boolean
save_as: actionable_main_slices
```
### 主线程文件 IO

- ID: `main_thread_file_io`
- Type: `skill`

```yaml
id: main_thread_file_io
type: skill
skill: main_thread_file_io_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
  min_dur_ns: 500000
  top_k: 10
display:
  level: key
  layer: deep
  show: false
  title: 主线程文件 IO Top10
  columns:
  - name: io_slice
    label: IO 切片
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: percent
    label: 区间占比
    type: percentage
    format: percentage
save_as: main_file_io
```
### Binder 调用分析

- ID: `binder_analysis`
- Type: `skill`

```yaml
id: binder_analysis
type: skill
skill: binder_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
display:
  level: key
  layer: deep
  show: false
  title: Binder 调用
  columns:
  - name: client_process
    label: 客户端
    type: string
  - name: server_process
    label: 服务端
    type: string
  - name: call_count
    label: 调用次数
    type: number
    format: compact
  - name: total_client_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_delay_ms
    label: 最大延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_delay_ms
    label: 平均延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: slow_calls
    label: 慢调用
    type: number
save_as: binder_calls
```
### 主线程同步 Binder

- ID: `main_thread_sync_binder`
- Type: `skill`

```yaml
id: main_thread_sync_binder
type: skill
skill: binder_blocking_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
display:
  level: key
  layer: deep
  show: false
  title: 主线程同步 Binder Top10
  columns:
  - name: server_process
    label: 对端进程
    type: string
  - name: interface
    label: 接口
    type: string
  - name: call_count
    label: 调用次数
    type: number
  - name: total_block_ms
    label: 总阻塞时间
    type: duration
    format: duration_ms
    unit: ms
  - name: server_exec_ms
    label: 服务端执行
    type: duration
    format: duration_ms
    unit: ms
  - name: max_block_ms
    label: 最大阻塞
    type: duration
    format: duration_ms
    unit: ms
  - name: is_main_blocked
    label: 主线程被阻
    type: boolean
save_as: main_sync_binder
```
### Binder 线程池分析

- ID: `binder_pool`
- Type: `skill`

```yaml
id: binder_pool
type: skill
skill: startup_binder_pool_analysis
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
  layer: deep
  title: Binder 线程池分析
  columns:
  - name: metric
    label: 指标
    type: string
  - name: value
    label: 值
    type: string
  - name: assessment
    label: 评估
    type: string
save_as: binder_pool
optional: true
```
### 调度延迟分析

- ID: `sched_latency`
- Type: `skill`

```yaml
id: sched_latency
type: skill
skill: main_thread_sched_latency_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
display:
  level: detail
  layer: deep
  show: false
  title: 主线程调度延迟
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: runnable_count
    label: 等待次数
    type: number
  - name: total_runnable_ms
    label: 总等待
    type: duration
    format: duration_ms
    unit: ms
  - name: max_latency_ms
    label: 最大延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_latency_ms
    label: 平均延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: long_wait_count
    label: '>2ms 次数'
    type: number
  - name: severe_count
    label: '>8ms 次数'
    type: number
save_as: sched_delay
```
### 主线程状态分布

- ID: `main_thread_state`
- Type: `skill`

```yaml
id: main_thread_state
type: skill
skill: startup_main_thread_states_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
  startup_id: ${startup_id}
  startup_type: ${startup_type}
display:
  level: key
  layer: deep
  show: false
  title: 主线程状态分布
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
  - name: io_wait
    label: io_wait
    type: number
    format: compact
  - name: evidence_strength
    label: 证据强度
    type: string
  - name: blocked_functions
    label: 阻塞函数
    type: string
    format: truncate
save_as: thread_states
```
### 启动关键任务

- ID: `critical_tasks`
- Type: `skill`

```yaml
id: critical_tasks
type: skill
skill: startup_critical_tasks
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  top_k: 15
display:
  level: key
  layer: deep
  title: 启动关键任务（全线程四象限）
  columns:
  - name: window_start_ts
    label: window_start_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_end_ts
    label: window_end_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: total_observed_threads
    label: total_observed_threads
    type: number
    hidden: true
  - name: thread_name
    label: 线程
    type: string
  - name: role
    label: 角色
    type: string
  - name: total_cpu_ms
    label: CPU 时间
    type: duration
    format: duration_ms
    unit: ms
  - name: q1_big_running_ms
    label: Q1 大核运行
    type: duration
    format: duration_ms
    unit: ms
  - name: q2_little_running_ms
    label: Q2 小核运行
    type: duration
    format: duration_ms
    unit: ms
  - name: q3_runnable_ms
    label: Q3 等待调度
    type: duration
    format: duration_ms
    unit: ms
  - name: q4b_sleeping_ms
    label: Q4b 睡眠等待
    type: duration
    format: duration_ms
    unit: ms
  - name: running_pct
    label: 运行占比
    type: percentage
    format: percentage
  - name: big_core_pct
    label: 大核占比
    type: percentage
    format: percentage
  - name: migrations
    label: 核迁移
    type: number
  - name: observed_cross_cluster_migrations
    label: 已确认跨 cluster 迁移
    type: number
  - name: unknown_cluster_migrations
    label: cluster 身份未知的迁移
    type: number
  - name: migration_evidence
    label: 迁移证据覆盖
    type: string
  - name: cross_cluster_migrations
    label: 跨 cluster
    type: number
  - name: upid
    label: UPID
    type: number
  - name: utid
    label: UTID
    type: number
  - name: priority_min
    label: 最小 kernel priority
    type: number
  - name: priority_max
    label: 最大 kernel priority
    type: number
  - name: priority_value_count
    label: priority 值数
    type: number
  - name: preemption_count
    label: 窗口内 R+ 切出次数
    type: number
  - name: runnable_preempted_ms
    label: R+ 等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: unknown_running_ms
    label: 未知核类型运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: scheduling_policy_evidence
    label: 调度策略证据
    type: string
  - name: other_state_ms
    label: 其他观测状态(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: pid
    label: PID
    type: number
    hidden: true
  - name: tid
    label: TID
    type: number
    hidden: true
  - name: process_name
    label: 进程
    type: string
    hidden: true
  - name: priority_evidence
    label: 优先级证据
    type: string
    hidden: true
  - name: q4a_uninterruptible_ms
    label: Q4a 不可中断等待(ms)
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
  - name: total_ms
    label: 总观测状态时间(ms)
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
save_as: critical_tasks
optional: true
```
### 关键任务系统证据与覆盖

- ID: `critical_task_system_evidence`
- Type: `skill`

```yaml
id: critical_task_system_evidence
type: skill
skill: thread_system_summary_in_range
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
  layer: deep
  title: 关键任务系统证据与覆盖
save_as: critical_task_system_evidence
optional: true
```
### 线程阻塞关系

- ID: `thread_blocking_graph`
- Type: `skill`

```yaml
id: thread_blocking_graph
type: skill
skill: startup_thread_blocking_graph
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  min_block_ms: 1
  top_k: 20
display:
  level: detail
  layer: deep
  title: 线程等待与唤醒证据
  columns:
  - name: is_unfinished
    label: 未结束等待
    type: number
  - name: left_censored
    label: 左边界裁剪
    type: number
  - name: right_censored
    label: 右边界裁剪
    type: number
  - name: wakeup_state_id
    label: 后继状态ID
    type: number
  - name: evidence_scope
    label: 证据范围
    type: string
  - name: waker_slice_id
    label: 唤醒时操作ID
    type: number
  - name: upid
    label: upid
    type: number
    hidden: true
  - name: utid
    label: utid
    type: number
    hidden: true
  - name: thread_state_id
    label: thread_state_id
    type: number
    hidden: true
  - name: raw_start_ts
    label: 原始等待开始
    type: timestamp
    unit: ns
  - name: raw_end_ts
    label: 原始等待结束
    type: timestamp
    unit: ns
  - name: start_ts
    label: 窗口内等待开始
    type: timestamp
    unit: ns
  - name: end_ts
    label: 窗口内等待结束
    type: timestamp
    unit: ns
  - name: wakeup_ts
    label: 后继事件时间
    type: timestamp
    unit: ns
  - name: wakeup_status
    label: 唤醒证据状态
    type: string
  - name: wakeup_count
    label: 有唤醒元数据的事件数
    type: number
  - name: waker_utid
    label: 唤醒线程身份
    type: number
  - name: waker_upid
    label: 唤醒进程身份
    type: number
  - name: observed_waker_utid
    label: 原始唤醒线程字段
    type: number
  - name: irq_context
    label: IRQ 上下文
    type: number
  - name: relation_status
    label: 关系证据边界
    type: string
  - name: waker_slice_status
    label: 唤醒时操作证据
    type: string
  - name: blocked_thread
    label: 等待线程
    type: string
  - name: blocked_role
    label: 等待线程角色
    type: string
  - name: blocked_state
    label: 等待状态
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
    format: code
  - name: waker_thread
    label: 唤醒者线程
    type: string
  - name: waker_process
    label: 唤醒者进程
    type: string
  - name: waker_current_slice
    label: 唤醒者当时操作
    type: string
  - name: block_count
    label: 等待区间数
    type: number
  - name: total_block_ms
    label: 窗口内等待时长
    type: duration
    format: duration_ms
    unit: ms
  - name: max_block_ms
    label: 单区间等待时长
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_block_ms
    label: 单区间等待时长
    type: duration
    format: duration_ms
    unit: ms
save_as: blocking_graph
optional: true
```
### JIT 影响分析

- ID: `jit_analysis`
- Type: `skill`

```yaml
id: jit_analysis
type: skill
skill: startup_jit_analysis
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
  layer: deep
  title: JIT 影响分析
  columns:
  - name: metric
    label: 指标
    type: string
  - name: value
    label: 值
    type: string
  - name: assessment
    label: 评估
    type: string
save_as: jit_analysis
optional: true
condition: '''${startup_type}'' === ''cold'''
```
### 热点 Slice 线程状态

- ID: `hot_slice_states`
- Type: `skill`

```yaml
id: hot_slice_states
type: skill
skill: startup_hot_slice_states
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  top_n: 10
display:
  level: detail
  layer: deep
  title: 热点 Slice 线程状态分布
  columns:
  - name: sample_rank
    label: 样本排名
    type: number
    format: compact
  - name: slice_id
    label: Slice ID
    type: number
    format: compact
  - name: upid
    label: UPID
    type: number
    format: compact
  - name: utid
    label: UTID
    type: number
    format: compact
  - name: pid
    label: PID
    type: number
    format: compact
  - name: tid
    label: TID
    type: number
    format: compact
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: slice_name
    label: 切片名
    type: string
  - name: slice_dur_ms
    label: 切片耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: slice_ts
    label: 开始时间
    type: timestamp
    unit: ns
  - name: slice_end_ts
    label: 结束时间
    type: timestamp
    unit: ns
  - name: raw_slice_ts
    label: 原始开始时间
    type: timestamp
    unit: ns
  - name: raw_slice_end_ts
    label: 原始结束时间
    type: timestamp
    unit: ns
  - name: raw_slice_dur_ms
    label: 原始耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: left_censored
    label: 左侧裁剪
    type: number
    format: compact
  - name: right_censored
    label: 右侧裁剪
    type: number
    format: compact
  - name: is_unfinished
    label: 未结束
    type: number
    format: compact
  - name: state
    label: 线程状态
    type: string
  - name: state_dur_ms
    label: 状态耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: state_pct
    label: 状态占比
    type: percentage
    format: percentage
  - name: state_coverage_ms
    label: 状态覆盖
    type: duration
    format: duration_ms
    unit: ms
  - name: state_coverage_pct
    label: 状态覆盖率
    type: percentage
    format: percentage
  - name: uncovered_ms
    label: 未覆盖时长
    type: duration
    format: duration_ms
    unit: ms
  - name: io_wait
    label: io_wait
    type: number
    format: compact
  - name: evidence_strength
    label: 证据强度
    type: string
  - name: blocked_functions
    label: 阻塞函数
    type: string
    format: truncate
  - name: sample_limit
    label: 样本上限
    type: number
    format: compact
  - name: sampling_scope
    label: 采样口径
    type: string
  - name: eligible_slice_count
    label: 候选 Slice 数
    type: number
    format: compact
  - name: selected_slice_count
    label: 入选 Slice 数
    type: number
    format: compact
save_as: hot_slice_states
optional: true
```
### 启动诊断

- ID: `startup_diagnosis`
- Type: `diagnostic`

```yaml
id: startup_diagnosis
type: diagnostic
display:
  level: key
  layer: deep
  title: 问题诊断
inputs:
- startup_basic
- cpu_core
- cpu_freq
- per_cpu_context
- preemption_handoffs
- freq_rampup
- quadrant
- cpu_placement
- main_slices
- actionable_main_slices
- main_file_io
- binder_calls
- main_sync_binder
- binder_pool
- sched_delay
- thread_states
- critical_tasks
- blocking_graph
- jit_analysis
- hot_slice_states
rules:
- condition: cpu_core.data[0]?.big_core_pct < 20 && cpu_core.data[0]?.unknown_core_pct === 0 && quadrant.data[0]?.q3_runnable_ms
    > 50
  severity: warning
  diagnosis: 主线程大核占比偏低（${cpu_core.data[0].big_core_pct}%）且 Runnable 排队明显（${quadrant.data[0].q3_runnable_ms}ms），可能存在调度供给不足
  confidence: medium
  suggestions:
  - 检查是否有其他高优先级进程抢占大核
  - 对照关键线程 kernel priority、R+ 切换和 affinity/cgroup 证据，再评估调度配置
- condition: cpu_core.data[0]?.unknown_core_pct > 0
  severity: info
  diagnosis: 主线程运行时间中 ${cpu_core.data[0].unknown_core_pct}% 的核类型未知，不能把未知部分计为小核或据此认定摆核不足
  confidence: medium
  suggestions:
  - 补充或检查 cpu_frequency/cpu capacity 数据后再判断大小核调度问题
- condition: quadrant.data[0]?.q3_runnable_ms > 50 && (sched_delay.data[0]?.severe_count || 0) > 3
  severity: warning
  diagnosis: 主线程 Runnable 等待 ${quadrant.data[0].q3_runnable_ms}ms，且存在 ${sched_delay.data[0].severe_count} 次 >8ms 调度延迟
  confidence: high
  suggestions:
  - 对照等待区间内的 CPU 交接、系统负载和目标线程可运行范围，确认是否存在资源竞争
  - 减少启动期间的并发线程数
- condition: quadrant.data[0]?.q4a_pct > 15 && ((main_file_io.data[0]?.percent || 0) > 2 || thread_states?.data?.find(r =>
    (r.evidence_strength === 'direct_io_wait' || r.evidence_strength === 'inferred_io_or_page_cache') && ((r.percent || 0)
    > 5)))
  severity: warning
  diagnosis: 主线程不可中断等待占比 ${quadrant.data[0].q4a_pct}%，并出现文件 I/O 或 io_wait/page-cache blocked_function 证据，属于 IO/page-cache
    等待候选
  confidence: medium
  suggestions:
  - 将数据库/文件读写操作移至后台线程
  - 使用异步 IO 或延迟加载策略
  - 检查 APK/DEX 文件读取是否在关键路径
- condition: quadrant.data[0]?.q4b_pct > 30 && ((main_sync_binder?.data?.find(r => r.is_main_blocked === 1)?.total_block_ms)
    || 0) > 20
  severity: warning
  diagnosis: 主线程睡眠等待(S 状态) 占比 ${quadrant.data[0].q4b_pct}% 且存在 Binder 阻塞证据
  confidence: medium
  suggestions:
  - 检查主线程同步 Binder 调用，改为异步
  - 减少启动期间的锁竞争
- condition: (main_file_io.data[0]?.total_ms > 50 || main_file_io.data[0]?.percent > 5) && ((quadrant.data[0]?.q4a_pct ||
    0) > 10 || (quadrant.data[0]?.q4b_pct || 0) > 20)
  severity: warning
  diagnosis: 主线程文件 IO '${main_file_io.data[0].io_slice}' 耗时 ${main_file_io.data[0].total_ms}ms（占比 ${main_file_io.data[0].percent}%）
  confidence: high
  suggestions:
  - 避免在首帧前执行文件读取/写入，改为预取或延迟加载
  - 数据库初始化改为异步，合并小 IO 为批量 IO
- condition: (((main_sync_binder?.data?.find(r => r.is_main_blocked === 1)?.total_block_ms) || 0) > 80 || ((main_sync_binder?.data?.find(r
    => r.is_main_blocked === 1)?.max_block_ms) || 0) > 16) && ((quadrant.data[0]?.q4b_pct || 0) > 15 || (quadrant.data[0]?.q3_runnable_ms
    || 0) > 20)
  severity: warning
  diagnosis: 主线程同步 Binder '${main_sync_binder.data.find(r => r.is_main_blocked === 1)?.interface}' 阻塞 ${main_sync_binder.data.find(r
    => r.is_main_blocked === 1)?.total_block_ms}ms
  confidence: high
  suggestions:
  - 将同步 Binder 改为异步或迁移到后台线程
  - 减少启动首屏前的跨进程依赖调用
- condition: binder_calls.data[0]?.total_client_ms > 100 && ((main_sync_binder?.data?.find(r => r.is_main_blocked === 1)?.total_block_ms)
    || 0) > 20
  severity: warning
  diagnosis: Binder 调用 ${binder_calls.data[0].server_process} 总耗时 ${binder_calls.data[0].total_client_ms}ms，且主线程存在同步 Binder
    阻塞
  confidence: high
  suggestions:
  - 减少启动期间的 IPC 调用
  - 使用异步 Binder 或延迟调用
- condition: (sched_delay.data[0]?.severe_count || 0) > 5 && (sched_delay.data[0]?.max_latency_ms || 0) > 8
  severity: warning
  diagnosis: 存在 ${sched_delay.data[0].severe_count} 次严重调度延迟 (>8ms)，最大延迟 ${sched_delay.data[0].max_latency_ms}ms
  confidence: medium
  suggestions:
  - 检查系统负载，减少后台进程
  - 核对抢占交接、线程 kernel priority 与实际调度策略；缺少策略证据时保留未知，不能仅凭等待总量建议改为 RT
- condition: ((actionable_main_slices.data[0]?.is_framework_wrapper || 0) === 0) && (actionable_main_slices.data[0]?.max_ms
    || 0) > 80 && (actionable_main_slices.data[0]?.percent || 0) > 15
  severity: warning
  diagnosis: 主线程可操作热点 '${actionable_main_slices.data[0].slice_name}' 最长耗时 ${actionable_main_slices.data[0].max_ms}ms（占比 ${actionable_main_slices.data[0].percent}%）
  confidence: high
  suggestions:
  - 优先下钻该切片内部子阶段，定位可迁移到后台的初始化任务
  - 将首帧前非关键任务延后到 TTID 之后执行
- condition: main_slices.data[0]?.max_ms > 100 && (main_slices.data[0]?.percent || 0) > 20 && !['clientTransactionExecuted',
    'activityStart', 'bindApplication'].includes(main_slices.data[0]?.slice_name || '') && !(main_slices.data[0]?.slice_name
    || '').startsWith('performCreate:')
  severity: warning
  diagnosis: 主线程操作 '${main_slices.data[0].slice_name}' 最长耗时 ${main_slices.data[0].max_ms}ms
  confidence: high
  suggestions:
  - 优化该操作或移到后台线程
  - 检查是否可以分批执行
- condition: (quadrant.data[0]?.q4b_pct || 0) > 25 && thread_states?.data?.find(r => r.state === 'S')?.percent > 20 && (thread_states?.data?.find(r
    => r.state === 'S')?.blocked_functions || '').includes('futex')
  severity: warning
  diagnosis: 主线程 S(Sleeping) 状态占比 ${thread_states.data.find(r => r.state === 'S').percent}%，blocked_functions 含 futex 相关函数，存在
    futex 路径等待；尚不能区分锁竞争、条件变量或线程 join
  confidence: medium
  suggestions:
  - 关联锁对象/持有者、竞争事件或对应调用栈，区分 mutex、条件变量和 join
  - 仅对确认影响关键路径的同步依赖提出修改
- condition: (quadrant.data[0]?.q4a_pct || 0) > 10 && thread_states?.data?.find(r => (r.evidence_strength === 'direct_io_wait'
    || r.evidence_strength === 'inferred_io_or_page_cache') && ((r.percent || 0) > 5))
  severity: warning
  diagnosis: 主线程 D/不可中断等待中出现 IO/page-cache 证据（${thread_states.data.find(r => r.evidence_strength === 'direct_io_wait' || r.evidence_strength
    === 'inferred_io_or_page_cache').total_dur_ms}ms），需要结合文件/DB slice 或 block I/O 进一步定因
  confidence: medium
  suggestions:
  - 将数据库/文件操作移至后台线程
  - 使用异步 IO 或延迟加载
- condition: (critical_tasks?.data?.find(t => t.role === 'jit')?.total_cpu_ms || 0) > 20 && (critical_tasks?.data?.find(t
    => t.role === 'jit')?.big_core_pct || 0) > 50
  severity: warning
  diagnosis: JIT 线程 CPU 时间 ${critical_tasks.data.find(t => t.role === 'jit').total_cpu_ms}ms（已分类大核占比 ${critical_tasks.data.find(t
    => t.role === 'jit').big_core_pct}%）；这是后台执行量，是否竞争需对齐主线程 Runnable 与同 CPU 区间
  confidence: medium
  suggestions:
  - 使用 Baseline Profile 减少冷启动 JIT 编译需求
  - 检查是否缺少 .prof 或 .dm 文件
- condition: (critical_tasks?.data?.find(t => t.role === 'main')?.cross_cluster_migrations || 0) > 10
  severity: warning
  diagnosis: 主线程观测到 ${critical_tasks.data.find(t => t.role === 'main').cross_cluster_migrations} 次跨 cluster 迁移；迁移本身不能证明缓存失效或启动延迟贡献
  confidence: medium
  suggestions:
  - 对照真实 cluster 拓扑、迁移时间与关键任务区间，必要时补充缓存/PMU 证据
  - 检查是否有其他线程/进程在启动期间与主线程争抢 CPU
- condition: critical_tasks?.data?.length > 0 && critical_tasks.data.reduce((sum, t) => sum + (t.total_cpu_ms || 0), 0) >
    ${dur_ms} * 2
  severity: info
  diagnosis: 返回的关键线程 CPU 时间合计 ${Math.round(critical_tasks.data.reduce((sum, t) => sum + (t.total_cpu_ms || 0), 0))}ms，是启动墙钟时间
    ${dur_ms}ms 的 ${(critical_tasks.data.reduce((sum, t) => sum + (t.total_cpu_ms || 0), 0) / ${dur_ms}).toFixed(1)} 倍，表明存在多核并行工作；是否竞争需检查实际
    Runnable 与抢占区间
  confidence: medium
  suggestions:
  - 结合逐核系统负载、关键线程 Runnable 和 R+ 交接，确认并行工作是否挤占关键路径
  - 只有确认干扰关键路径后，才考虑降低后台并发或延迟非关键初始化
- condition: (blocking_graph?.data?.find(b => b.blocked_role === 'main' && b.waker_process === 'system_server')?.total_block_ms
    || 0) > 30
  severity: warning
  diagnosis: 观测到一次主线程等待 ${blocking_graph.data.find(b => b.blocked_role === 'main' && b.waker_process === 'system_server').total_block_ms}ms
    后由 system_server 唤醒；唤醒者不等于等待发起方，不能把整段等待归因给 system_server
  confidence: medium
  suggestions:
  - 对齐实际 Binder transaction/reply 或同步依赖，确认等待与对端工作是否连接
  - 检查启动期间是否有密集的跨进程 Binder 调用
- condition: (blocking_graph?.data?.find(b => b.blocked_role === 'main' && b.waker_thread === 'HeapTaskDaemon')?.total_block_ms
    || 0) > 10
  severity: warning
  diagnosis: 观测到主线程等待 ${blocking_graph.data.find(b => b.blocked_role === 'main' && b.waker_thread === 'HeapTaskDaemon').total_block_ms}ms
    后由 HeapTaskDaemon 唤醒；是否由 GC 引起等待仍需暂停/锁依赖证据
  confidence: medium
  suggestions:
  - 若确认 GC 暂停或锁依赖进入启动关键路径，再检查对象分配
  - 避免在 Application.onCreate() 中创建大量临时对象
- condition: freq_rampup?.data?.some(r => r.rampup_pct > 50)
  severity: info
  diagnosis: UCPU ${freq_rampup.data.find(r => r.rampup_pct > 50).ucpu} 的后段频率比初期高 ${freq_rampup.data.find(r => r.rampup_pct
    > 50).rampup_pct}%；这是覆盖完整的阶段观测，不能直接判定升频延迟或启动损失
  confidence: high
  suggestions:
  - 对齐该 CPU 上关键任务、DVFS 请求/限制及频率响应，再评估是否影响关键路径
- condition: cpu_placement?.data?.length > 2 && cpu_placement.data[0]?.big_core_pct != null && cpu_placement.data[2]?.big_core_pct
    != null && cpu_placement.data[0].big_core_pct < 20 && cpu_placement.data[2].big_core_pct > 60
  severity: info
  diagnosis: 主线程已分类大核占比从初期 ${cpu_placement.data[0].big_core_pct}% 变为后段 ${cpu_placement.data[2].big_core_pct}%；需保留未知核占比，不能据此认定被困小核或亲和性配置错误
  confidence: medium
  suggestions:
  - 结合实际 CPU 容量、核驻留时间及任务需求说明变化；未知拓扑保持未知
- condition: binder_pool?.data?.find(r => r.metric === '线程池利用率')?.value?.includes('⚠️')
  severity: warning
  diagnosis: Binder 线程池利用率过高，新的 Binder 回复可能排队等待
  confidence: medium
  suggestions:
  - 减少启动期间并行的 Binder 调用
  - 将非关键 IPC 延迟到首帧之后
```
## Output and evidence contract

```yaml
display:
  level: key
  format: summary
```
