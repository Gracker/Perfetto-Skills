GENERATED FILE - DO NOT EDIT.
Source: backend/skills/deep/cpu_profiling.skill.yaml
Source SHA-256: 747b9f8972708ad1e4c8449ab8e9876c58138f44ae4f3515d87232a9173a4772
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# CPU 深度调优

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_profiling
version: '3.0'
type: deep
category: deep_analysis
tier: S
```

## Metadata

```yaml
display_name: CPU 深度调优
description: 综合分析 Scheduling, Frequency, Idle 状态
icon: settings_suggest
tags:
- cpu
- profiling
- deep
level: 2
```

## Triggers

```yaml
keywords:
  zh:
  - CPU剖析
  - 调度延迟
  - 大小核
  - CPU效率
  - 上下文切换
  - 性能分析
  en:
  - cpu profiling
  - scheduling latency
  - big little
  - cpu efficiency
  - context switch
patterns:
- .*CPU.*剖析.*
- .*调度.*延迟.*
- .*性能.*分析.*
```

## Prerequisites

```yaml
modules:
- linux.cpu.frequency
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选）
- name: min_runtime_ms
  type: number
  required: false
  default: 1
  description: 最小运行时长阈值（毫秒）
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
### CPU 使用概览

- ID: `cpu_usage_overview`
- Type: `atomic`
- SQL: [`../sql/cpu_profiling/cpu_usage_overview.sql`](../sql/cpu_profiling/cpu_usage_overview.sql)

```yaml
id: cpu_usage_overview
type: atomic
optional: true
synthesize:
  role: overview
  fields:
  - key: core_type
    label: 核心类型
  - key: total_runtime_ms
    label: 总运行时间
    format: '{{value}} ms'
  - key: total_slices
    label: 总切片数
  insights:
  - condition: core_type === 'big' && total_runtime_ms > 1000
    template: 大核集群运行 {{total_runtime_ms}}ms，使用活跃
display:
  level: summary
  layer: overview
  title: CPU 概览
  columns:
  - name: core_type
    label: 核心类型
    type: string
  - name: core_count
    label: 核心数
    type: number
  - name: total_runtime_ms
    label: 总运行时间
    type: duration
    format: duration_ms
    unit: ms
  - name: total_slices
    label: 总切片数
    type: number
    format: compact
  - name: avg_capacity
    label: 平均容量
    type: number
    format: compact
save_as: cpu_overview
```
### 进程 CPU 时间

- ID: `process_cpu_time`
- Type: `atomic`
- SQL: [`../sql/cpu_profiling/process_cpu_time.sql`](../sql/cpu_profiling/process_cpu_time.sql)

```yaml
id: process_cpu_time
type: atomic
display:
  level: detail
  layer: list
  title: 进程 CPU 使用排行
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: pid
    label: PID
    type: number
  - name: cpu_time_ms
    label: CPU 时间
    type: duration
    format: duration_ms
    unit: ms
  - name: slice_count
    label: 切片数
    type: number
    format: compact
  - name: cpus_used
    label: 使用 CPU 数
    type: number
  - name: avg_slice_ms
    label: 平均切片时长
    type: duration
    format: duration_ms
    unit: ms
save_as: process_cpu_time
```
### 线程 CPU 时间

- ID: `thread_cpu_time`
- Type: `atomic`
- SQL: [`../sql/cpu_profiling/thread_cpu_time.sql`](../sql/cpu_profiling/thread_cpu_time.sql)

```yaml
id: thread_cpu_time
type: atomic
display:
  level: detail
  layer: list
  title: 线程 CPU 使用排行
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: tid
    label: TID
    type: number
  - name: process_name
    label: 进程
    type: string
  - name: cpu_time_ms
    label: CPU 时间
    type: duration
    format: duration_ms
    unit: ms
  - name: slice_count
    label: 切片数
    type: number
    format: compact
  - name: avg_slice_ms
    label: 平均切片时长
    type: duration
    format: duration_ms
    unit: ms
save_as: thread_cpu_time
```
### 大小核分布

- ID: `core_distribution`
- Type: `atomic`
- SQL: [`../sql/cpu_profiling/core_distribution.sql`](../sql/cpu_profiling/core_distribution.sql)

```yaml
id: core_distribution
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 大小核调度分布
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: tid
    label: TID
    type: number
  - name: process_name
    label: 进程
    type: string
  - name: total_ms
    label: 总运行时间
    type: duration
    format: duration_ms
    unit: ms
  - name: big_core_pct
    label: 大核占比
    type: percentage
    format: percentage
  - name: medium_core_pct
    label: 中核占比
    type: percentage
    format: percentage
  - name: little_core_pct
    label: 小核占比
    type: percentage
    format: percentage
save_as: core_distribution
```
### 调度延迟

- ID: `scheduling_latency`
- Type: `atomic`
- SQL: [`../sql/cpu_profiling/scheduling_latency.sql`](../sql/cpu_profiling/scheduling_latency.sql)

```yaml
id: scheduling_latency
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 调度延迟分析
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: tid
    label: TID
    type: number
  - name: process_name
    label: 进程
    type: string
  - name: runnable_count
    label: 可运行次数
    type: number
    format: compact
  - name: total_latency_ms
    label: 总延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_latency_ms
    label: 平均延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: max_latency_ms
    label: 最大延迟
    type: duration
    format: duration_ms
    unit: ms
save_as: scheduling_latency
```
### 上下文切换

- ID: `context_switches`
- Type: `atomic`
- SQL: [`../sql/cpu_profiling/context_switches.sql`](../sql/cpu_profiling/context_switches.sql)

```yaml
id: context_switches
type: atomic
display:
  level: detail
  layer: deep
  title: 上下文切换分析
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: tid
    label: TID
    type: number
  - name: process_name
    label: 进程
    type: string
  - name: switch_count
    label: 切换次数
    type: number
    format: compact
  - name: runtime_ms
    label: 运行时间
    type: duration
    format: duration_ms
    unit: ms
  - name: switches_per_sec
    label: 切换频率(/s)
    type: number
    format: compact
save_as: context_switches
```
### CPU 使用时间线

- ID: `cpu_timeline`
- Type: `atomic`
- SQL: [`../sql/cpu_profiling/cpu_timeline.sql`](../sql/cpu_profiling/cpu_timeline.sql)

```yaml
id: cpu_timeline
type: atomic
display:
  level: detail
  layer: deep
  title: CPU 使用趋势
  columns:
  - name: second
    label: 时间(s)
    type: number
  - name: active_cpus
    label: 活跃 CPU 数
    type: number
  - name: total_cpu_ms
    label: 总 CPU 时间
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_per_cpu_ms
    label: 每核平均
    type: duration
    format: duration_ms
    unit: ms
save_as: cpu_timeline
```
### CPU 剖析结论

- ID: `profiling_conclusion`
- Type: `atomic`
- SQL: [`../sql/cpu_profiling/profiling_conclusion.sql`](../sql/cpu_profiling/profiling_conclusion.sql)

```yaml
id: profiling_conclusion
type: atomic
optional: true
synthesize:
  role: conclusion
  fields:
  - key: top_cpu_thread
    label: CPU 最高线程
  - key: latency_severity
    label: 延迟评级
  - key: suggestion
    label: 建议
  insights:
  - condition: latency_severity === 'high_latency'
    template: 调度延迟严重：{{top_cpu_thread}} 占用最高，最大延迟 {{worst_sched_latency_ms}}ms
  - condition: latency_severity === 'moderate_latency'
    template: 调度延迟中等，关注 {{top_cpu_thread}}
display:
  level: summary
  layer: overview
  title: CPU 性能分析结论
  columns:
  - name: top_cpu_thread
    label: CPU 占用最高线程
    type: string
  - name: top_thread_cpu_ms
    label: CPU 时间
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_sched_latency_ms
    label: 平均调度延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: worst_sched_latency_ms
    label: 最大调度延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_big_core_usage_pct
    label: 大核使用率
    type: percentage
    format: percentage
  - name: latency_severity
    label: 延迟评级
    type: string
  - name: suggestion
    label: 建议
    type: string
```
