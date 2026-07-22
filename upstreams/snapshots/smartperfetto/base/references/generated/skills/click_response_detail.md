GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/click_response_detail.skill.yaml
Source SHA-256: 3bf411e6c0f6db9de2434fb0ad420cb0a0140388c5968306f5ad569b3ff0c3e7
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# 点击详情分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: click_response_detail
version: '2.0'
type: composite
category: interaction
tier: S
```

## Metadata

```yaml
display_name: 点击详情分析
description: 深入分析单个点击事件的处理流程
icon: gesture
tags:
- click
- detail
- interaction
- composite
```

## Prerequisites

```yaml
required_tables:
- thread
- process
- thread_state
- sched_slice
modules:
- android.input
- android.binder
- linux.cpu.frequency
```

## Inputs

```yaml
- name: event_ts
  type: timestamp
  required: true
  description: 事件开始时间戳(ns)
- name: event_end_ts
  type: timestamp
  required: true
  description: 事件结束时间戳(ns)
- name: total_ms
  type: number
  required: true
  description: dispatch-to-ACK 总延迟(ms)
- name: dispatch_ms
  type: number
  required: false
  description: 分发延迟(ms)
- name: handling_ms
  type: number
  required: false
  description: 处理延迟(ms)
- name: event_type
  type: string
  required: false
  description: 事件类型
- name: event_action
  type: string
  required: false
  description: 事件动作
- name: process_name
  type: string
  required: true
  description: 进程名
- name: perfetto_start
  type: timestamp
  required: false
  description: Perfetto 跳转开始时间
- name: perfetto_end
  type: timestamp
  required: false
  description: Perfetto 跳转结束时间
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
### 事件基本信息

- ID: `event_info`
- Type: `atomic`
- SQL: [`../sql/click_response_detail/event_info.sql`](../sql/click_response_detail/event_info.sql)

```yaml
id: event_info
type: atomic
display:
  level: key
  layer: deep
  title: 事件详情
  columns:
  - name: event_type
    label: 事件类型
    type: string
  - name: event_action
    label: 事件动作
    type: string
  - name: process_name
    label: 进程名
    type: string
  - name: total_ms
    label: 总延迟(ACK)
    type: duration
    format: duration_ms
  - name: dispatch_ms
    label: 分发延迟(ms)
    type: duration
    format: duration_ms
  - name: handling_ms
    label: 处理延迟(ms)
    type: duration
    format: duration_ms
  - name: event_ts
    label: 事件开始
    type: timestamp
    clickAction: navigate_timeline
  - name: event_end_ts
    label: 事件结束
    type: timestamp
    clickAction: navigate_timeline
  - name: perfetto_start
    label: Perfetto开始
    type: timestamp
    clickAction: navigate_range
  - name: perfetto_end
    label: Perfetto结束
    type: timestamp
    clickAction: navigate_timeline
  - name: main_bottleneck
    label: 主要瓶颈
    type: string
  - name: rating
    label: 评级
    type: string
save_as: event_basic
```
### 输入分发管线分解

- ID: `input_dispatch_breakdown`
- Type: `atomic`
- SQL: [`../sql/click_response_detail/input_dispatch_breakdown.sql`](../sql/click_response_detail/input_dispatch_breakdown.sql)

```yaml
id: input_dispatch_breakdown
type: atomic
display:
  level: detail
  layer: deep
  title: 输入分发管线 (kernel→InputDispatcher→App)
  columns:
  - name: stage
    label: 管线阶段
    type: string
  - name: start_ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
  - name: thread_name
    label: 线程
    type: string
  - name: detail
    label: 详情
    type: string
optional: true
```
### 输入管线生命周期

- ID: `input_pipeline_lifecycle`
- Type: `atomic`
- SQL: [`../sql/click_response_detail/input_pipeline_lifecycle.sql`](../sql/click_response_detail/input_pipeline_lifecycle.sql)

```yaml
id: input_pipeline_lifecycle
type: atomic
optional: true
display:
  level: detail
  layer: deep
  title: 输入管线 5 阶段追踪 (Reader→Dispatch→Receive→Consume→Frame)
  columns:
  - name: input_id
    label: 输入事件 ID
    type: string
  - name: channel
    label: 事件通道
    type: string
  - name: total_latency_ms
    label: 总延迟(ACK)
    type: duration
    format: duration_ms
  - name: reader_ts
    label: Reader 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: reader_ms
    label: Reader(ms)
    type: duration
    format: duration_ms
  - name: dispatch_ts
    label: Dispatch 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dispatch_ms
    label: Dispatch(ms)
    type: duration
    format: duration_ms
  - name: receive_ts
    label: Receive 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: receive_ms
    label: Receive(ms)
    type: duration
    format: duration_ms
  - name: consume_ts
    label: Consume 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: consume_ms
    label: Consume(ms)
    type: duration
    format: duration_ms
  - name: frame_ts
    label: Frame 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: frame_ms
    label: Frame(ms)
    type: duration
    format: duration_ms
  - name: is_speculative_frame
    label: 推测帧
    type: boolean
save_as: input_lifecycle
```
### 大小核占比分析

- ID: `cpu_core_analysis`
- Type: `atomic`
- SQL: [`../sql/click_response_detail/cpu_core_analysis.sql`](../sql/click_response_detail/cpu_core_analysis.sql)

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
    type: number
  - name: little_core_ms
    label: 小核运行(ms)
    type: number
  - name: total_running_ms
    label: 总运行(ms)
    type: number
  - name: big_core_pct
    label: 大核占比(%)
    type: percentage
    format: percentage
  - name: little_core_pct
    label: 小核占比(%)
    type: percentage
    format: percentage
  - name: running_pct
    label: 运行占总时长(%)
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
### 四大象限分析

- ID: `quadrant_analysis`
- Type: `atomic`
- SQL: [`../sql/click_response_detail/quadrant_analysis.sql`](../sql/click_response_detail/quadrant_analysis.sql)

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
    type: number
  - name: q2_little_running_ms
    label: Q2小核运行(ms)
    type: number
  - name: q3_runnable_ms
    label: Q3可运行等待(ms)
    type: number
  - name: q4_sleeping_ms
    label: Q4睡眠阻塞(ms)
    type: number
  - name: total_ms
    label: 总时长(ms)
    type: number
  - name: runnable_pct
    label: Runnable占比(%)
    type: percentage
    format: percentage
  - name: sleeping_pct
    label: Sleeping占比(%)
    type: percentage
    format: percentage
  - name: classify_method
    label: 核判定来源
    type: string
save_as: quadrant
```
### 阻塞原因分析

- ID: `blocking_analysis`
- Type: `skill`

```yaml
id: blocking_analysis
type: skill
skill: main_thread_states_in_range
display:
  level: key
  layer: deep
  title: 阻塞原因 Top5
  columns:
  - name: state
    label: 状态
    type: string
  - name: state_desc
    label: 状态说明
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
    format: code
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: pct
    label: 区间占比
    type: percentage
    format: percentage
  - name: count
    label: 次数
    type: number
    format: compact
params:
  start_ts: ${event_ts}
  end_ts: ${event_end_ts}
  package: ${process_name}
  top_k: 5
save_as: blocking
```
### Binder 调用分析

- ID: `binder_analysis`
- Type: `skill`

```yaml
id: binder_analysis
type: skill
skill: binder_in_range
display:
  level: key
  layer: deep
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
params:
  start_ts: ${event_ts}
  end_ts: ${event_end_ts}
  package: ${process_name}
save_as: binder_calls
```
### 主线程同步 Binder

- ID: `main_thread_sync_binder`
- Type: `skill`

```yaml
id: main_thread_sync_binder
type: skill
skill: binder_blocking_in_range
display:
  level: key
  layer: deep
  title: 主线程同步 Binder
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
params:
  start_ts: ${event_ts}
  end_ts: ${event_end_ts}
  package: ${process_name}
save_as: main_sync_binder
```
### 调度延迟分析

- ID: `sched_latency`
- Type: `skill`

```yaml
id: sched_latency
type: skill
skill: main_thread_sched_latency_in_range
display:
  level: detail
  layer: deep
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
params:
  start_ts: ${event_ts}
  end_ts: ${event_end_ts}
  package: ${process_name}
save_as: sched_delay
```
### 主线程文件 IO

- ID: `main_thread_file_io`
- Type: `skill`

```yaml
id: main_thread_file_io
type: skill
skill: main_thread_file_io_in_range
display:
  level: detail
  layer: deep
  title: 主线程文件 IO
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
params:
  start_ts: ${event_ts}
  end_ts: ${event_end_ts}
  package: ${process_name}
  min_dur_ns: 500000
  top_k: 10
save_as: main_file_io
```
### 慢点击诊断

- ID: `click_diagnosis`
- Type: `diagnostic`

```yaml
id: click_diagnosis
type: diagnostic
display:
  level: key
  layer: deep
  title: 问题诊断
inputs:
- event_basic
- cpu_core
- quadrant
- blocking
- binder_calls
- main_sync_binder
- sched_delay
- main_file_io
rules:
- condition: quadrant.data[0]?.q3_runnable_ms > 20 && (sched_delay.data[0]?.severe_count || 0) > 0
  severity: warning
  diagnosis: 主线程 Runnable 等待 ${quadrant.data[0].q3_runnable_ms}ms，且存在 ${sched_delay.data[0].severe_count} 次 >8ms 调度延迟
  confidence: high
  suggestions:
  - CPU 资源争抢，检查后台线程负载
  - 减少并发任务
- condition: quadrant.data[0]?.sleeping_pct > 50 && ((main_file_io.data[0]?.percent || 0) > 2 || ((main_sync_binder?.data?.find(r
    => r.is_main_blocked === 1)?.total_block_ms) || 0) > 15)
  severity: warning
  diagnosis: 主线程 Sleeping 占比 ${quadrant.data[0].sleeping_pct}% 且存在 IO/Binder 阻塞证据
  confidence: medium
  suggestions:
  - 检查主线程阻塞原因
  - 将阻塞操作移到后台线程
- condition: cpu_core.data[0]?.big_core_pct < 20 && cpu_core.data[0]?.total_running_ms > 20 && quadrant.data[0]?.q3_runnable_ms
    > 20 && (sched_delay.data[0]?.severe_count || 0) > 0 && !(cpu_core.data[0]?.classify_method || '').includes('cpu_id_fallback')
  severity: warning
  diagnosis: 主线程大核占比偏低（${cpu_core.data[0].big_core_pct}%）且 Runnable 等待 ${quadrant.data[0].q3_runnable_ms}ms，存在调度供给不足迹象
  confidence: medium
  suggestions:
  - 检查是否有高优先级线程长期占用大核
  - 减少点击关键路径中的并发争抢
- condition: (cpu_core.data[0]?.classify_method || '').includes('cpu_id_fallback')
  severity: info
  diagnosis: 核类型判定回退到 CPU 编号阈值，大小核相关结论置信度有限
  confidence: medium
  suggestions:
  - 补充或检查 cpu_frequency/cpu capacity 数据后再判断大小核调度问题
- condition: (main_file_io.data[0]?.total_ms > 20 || main_file_io.data[0]?.percent > 5) && (quadrant.data[0]?.sleeping_pct
    || 0) > 20
  severity: warning
  diagnosis: 主线程文件 IO '${main_file_io.data[0].io_slice}' 耗时 ${main_file_io.data[0].total_ms}ms（占比 ${main_file_io.data[0].percent}%）
  confidence: high
  suggestions:
  - 避免在点击关键路径执行同步文件读写
  - 将数据库/文件访问改为异步或延后
- condition: binder_calls.data[0]?.total_client_ms > 30 && ((main_sync_binder?.data?.find(r => r.is_main_blocked === 1)?.total_block_ms)
    || 0) > 10
  severity: warning
  diagnosis: Binder 调用 ${binder_calls.data[0].server_process} 耗时 ${binder_calls.data[0].total_client_ms}ms，且主线程同步 Binder 阻塞明显
  confidence: high
  suggestions:
  - 将 Binder 调用移到后台线程
  - 使用异步 Binder
```
## Output and evidence contract

```yaml
display:
  level: key
  format: summary
```
