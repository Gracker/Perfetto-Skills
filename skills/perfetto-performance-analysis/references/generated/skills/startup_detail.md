GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/startup_detail.skill.yaml
Source SHA-256: 27c99e2bb5d9588e4ca6909bfd0a637f393af0211b692cc814005a00e99154c6
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
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
save_as: cpu_freq
```
### CPU 频率爬升

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
  title: CPU 频率爬升分析
  columns:
  - name: core_type
    label: 核类型
    type: string
  - name: early_avg_freq_mhz
    label: 初期均频(MHz)
    type: number
  - name: steady_avg_freq_mhz
    label: 稳态均频(MHz)
    type: number
  - name: rampup_pct
    label: 爬升幅度
    type: percentage
    format: percentage
  - name: assessment
    label: 评估
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
  - name: q4a_io_blocked_ms
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
  - name: avg_ms
    label: 平均耗时
    type: duration
    format: duration_ms
  - name: max_ms
    label: 最大耗时
    type: duration
    format: duration_ms
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
  - name: avg_ms
    label: 平均耗时
    type: duration
    format: duration_ms
  - name: max_ms
    label: 最大耗时
    type: duration
    format: duration_ms
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
  - name: max_delay_ms
    label: 最大延迟
    type: duration
    format: duration_ms
  - name: avg_delay_ms
    label: 平均延迟
    type: duration
    format: duration_ms
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
  - name: server_exec_ms
    label: 服务端执行
    type: duration
    format: duration_ms
  - name: max_block_ms
    label: 最大阻塞
    type: duration
    format: duration_ms
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
  - name: max_latency_ms
    label: 最大延迟
    type: duration
    format: duration_ms
  - name: avg_latency_ms
    label: 平均延迟
    type: duration
    format: duration_ms
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
  - name: cross_cluster_migrations
    label: 跨 cluster
    type: number
save_as: critical_tasks
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
  title: 线程阻塞关系图
  columns:
  - name: blocked_thread
    label: 被阻塞线程
    type: string
  - name: blocked_state
    label: 阻塞状态
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
    format: code
  - name: waker_thread
    label: 唤醒者
    type: string
  - name: waker_process
    label: 唤醒者进程
    type: string
  - name: waker_current_slice
    label: 唤醒者操作
    type: string
  - name: total_block_ms
    label: 总阻塞
    type: duration
    format: duration_ms
    unit: ms
  - name: block_count
    label: 次数
    type: number
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
  - name: blocked_functions
    label: 阻塞函数
    type: string
    format: truncate
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
- condition: cpu_core.data[0]?.big_core_pct < 20 && quadrant.data[0]?.q3_runnable_ms > 50 && !(cpu_core.data[0]?.classify_method
    || '').includes('cpu_id_fallback')
  severity: warning
  diagnosis: 主线程大核占比偏低（${cpu_core.data[0].big_core_pct}%）且 Runnable 排队明显（${quadrant.data[0].q3_runnable_ms}ms），可能存在调度供给不足
  confidence: medium
  suggestions:
  - 检查是否有其他高优先级进程抢占大核
  - 考虑调整进程优先级或使用 setThreadPriority
- condition: (cpu_core.data[0]?.classify_method || '').includes('cpu_id_fallback')
  severity: info
  diagnosis: 核类型判定回退到 CPU 编号阈值，大小核相关结论置信度有限
  confidence: medium
  suggestions:
  - 补充或检查 cpu_frequency/cpu capacity 数据后再判断大小核调度问题
- condition: quadrant.data[0]?.q3_runnable_ms > 50 && (sched_delay.data[0]?.severe_count || 0) > 3
  severity: warning
  diagnosis: 主线程 Runnable 等待 ${quadrant.data[0].q3_runnable_ms}ms，且存在 ${sched_delay.data[0].severe_count} 次 >8ms 调度延迟
  confidence: high
  suggestions:
  - CPU 资源争抢严重，检查后台线程负载
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
  - 考虑使用 SCHED_FIFO 策略
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
  diagnosis: 主线程 S(Sleeping) 状态占比 ${thread_states.data.find(r => r.state === 'S').percent}%，blocked_functions 含 futex 相关函数，存在锁竞争
  confidence: high
  suggestions:
  - 检查主线程是否存在锁竞争（synchronized/ReentrantLock）
  - 减少启动期间的线程同步操作
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
  diagnosis: JIT 线程 CPU 时间 ${critical_tasks.data.find(t => t.role === 'jit').total_cpu_ms}ms（大核占比 ${critical_tasks.data.find(t
    => t.role === 'jit').big_core_pct}%），可能与主线程争抢大核
  confidence: medium
  suggestions:
  - 使用 Baseline Profile 减少冷启动 JIT 编译需求
  - 检查是否缺少 .prof 或 .dm 文件
- condition: (critical_tasks?.data?.find(t => t.role === 'render')?.total_cpu_ms || 0) > 5 && (critical_tasks?.data?.find(t
    => t.role === 'render')?.big_core_pct || 0) < 30
  severity: info
  diagnosis: RenderThread 大核占比仅 ${critical_tasks.data.find(t => t.role === 'render').big_core_pct}%，首帧渲染可能因小核性能不足而变慢
  confidence: medium
  suggestions:
  - 检查 RenderThread 是否被调度到小核运行
  - 大量 GPU 指令在小核上提交会增加 TTID
- condition: (critical_tasks?.data?.find(t => t.role === 'main')?.cross_cluster_migrations || 0) > 10
  severity: warning
  diagnosis: 主线程跨 cluster 核迁移 ${critical_tasks.data.find(t => t.role === 'main').cross_cluster_migrations} 次，L2 Cache 反复失效导致性能损失
  confidence: high
  suggestions:
  - 频繁跨 cluster 迁移说明调度器未稳定分配核心
  - 检查是否有其他线程/进程在启动期间与主线程争抢 CPU
- condition: critical_tasks?.data?.length > 0 && critical_tasks.data.reduce((sum, t) => sum + (t.total_cpu_ms || 0), 0) >
    ${dur_ms} * 2
  severity: info
  diagnosis: 所有线程总 CPU 时间 ${Math.round(critical_tasks.data.reduce((sum, t) => sum + (t.total_cpu_ms || 0), 0))}ms 是启动墙钟时间
    ${dur_ms}ms 的 ${(critical_tasks.data.reduce((sum, t) => sum + (t.total_cpu_ms || 0), 0) / ${dur_ms}).toFixed(1)} 倍，CPU
    争抢激烈
  confidence: medium
  suggestions:
  - 减少启动期间的后台线程并发
  - 延迟非关键初始化到首帧之后
- condition: (blocking_graph?.data?.find(b => b.blocked_role === 'main' && b.waker_process === 'system_server')?.total_block_ms
    || 0) > 30
  severity: warning
  diagnosis: 主线程被 system_server 阻塞 ${blocking_graph.data.find(b => b.blocked_role === 'main' && b.waker_process === 'system_server').total_block_ms}ms（函数：${blocking_graph.data.find(b
    => b.blocked_role === 'main' && b.waker_process === 'system_server').blocked_function}）
  confidence: high
  suggestions:
  - system_server 处理延迟可能因系统负载高
  - 检查启动期间是否有密集的跨进程 Binder 调用
- condition: (blocking_graph?.data?.find(b => b.blocked_role === 'main' && b.waker_thread === 'HeapTaskDaemon')?.total_block_ms
    || 0) > 10
  severity: warning
  diagnosis: 主线程被 GC 阻塞 ${blocking_graph.data.find(b => b.blocked_role === 'main' && b.waker_thread === 'HeapTaskDaemon').total_block_ms}ms
  confidence: high
  suggestions:
  - 减少启动期间的对象分配
  - 避免在 Application.onCreate() 中创建大量临时对象
- condition: freq_rampup?.data?.find(r => r.core_type === 'big' || r.core_type === 'prime')?.rampup_pct > 50
  severity: info
  diagnosis: 启动初期大核频率比稳态低 ${freq_rampup.data.find(r => r.core_type === 'big' || r.core_type === 'prime').rampup_pct}%，存在升频延迟
  confidence: medium
  suggestions:
  - 冷启动初期 CPU 可能从低频 idle 唤醒，Governor 需要几个调度周期才升频
  - Qualcomm WALT 和 Pixel schedutil 的升频速度不同，可查看厂商特定优化
- condition: cpu_placement?.data?.length > 2 && (cpu_placement.data[0]?.big_core_pct || 0) < 20 && (cpu_placement.data[2]?.big_core_pct
    || 0) > 60
  severity: warning
  diagnosis: 启动前 100ms 主线程大核占比仅 ${cpu_placement.data[0].big_core_pct}%，之后升至 ${cpu_placement.data[2].big_core_pct}%。启动初期被困在小核
  confidence: medium
  suggestions:
  - 可能因 Zygote fork 继承了小核亲和性，或 top-app cgroup 设置有延迟
  - bindApplication 阶段的性能受此影响最大
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
