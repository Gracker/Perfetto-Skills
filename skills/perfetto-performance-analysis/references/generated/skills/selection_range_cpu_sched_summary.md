GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/selection_range_cpu_sched_summary.skill.yaml
Source SHA-256: c970063c31991780a831d4c680bca4f241addf9eecef9565c54d93c113652151
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 选区 CPU 调度与频率摘要

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: selection_range_cpu_sched_summary
version: '1.0'
type: composite
category: kernel
tier: B
```

## Metadata

```yaml
display_name: 选区 CPU 调度与频率摘要
description: 面向用户选区/可见窗口的快速 CPU 摆核、Running 排名、四象限和频率分布分析
icon: speed
tags:
- selection
- range
- cpu
- sched
- frequency
- quadrant
- migration
- quick
```

## Triggers

```yaml
keywords:
  zh:
  - 选区
  - 这一段
  - 这段
  - 摆核
  - 核心摆放
  - 平均频率
  - 频率分布
  - Running 排名
  - 四象限
  en:
  - selection range
  - current window
  - cpu placement
  - core placement
  - average frequency
  - frequency distribution
  - running ranking
  - quadrant
patterns:
- .*(选区|这段|这一段).*(CPU|摆核|核心|频率|Running|四象限).*
- .*(selected|current).*(range|window).*(cpu|core|frequency|running|quadrant).*
```

## Prerequisites

```yaml
required_tables:
- thread_state
- thread
- process
modules:
- sched
- linux.cpu.frequency
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 选区起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 选区结束时间戳(ns)
- name: package
  type: string
  required: false
  description: 可选进程名过滤，支持 GLOB 前缀匹配
- name: thread_name
  type: string
  required: false
  description: 可选线程名包含匹配
- name: top_k
  type: number
  required: false
  description: 线程/进程排名返回数量
- name: freq_bucket_mhz
  type: number
  required: false
  description: 频率分布桶大小，单位 MHz
```

## Ordered execution

### 初始化 CPU 拓扑

- ID: `init_cpu_topology`
- Type: `skill`

```yaml
id: init_cpu_topology
type: skill
skill: cpu_topology_view
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: hidden
optional: true
```
### Running 线程四象限与摆核

- ID: `running_thread_quadrants`
- Type: `atomic`
- SQL: [`../sql/selection_range_cpu_sched_summary/running_thread_quadrants.sql`](../sql/selection_range_cpu_sched_summary/running_thread_quadrants.sql)

```yaml
id: running_thread_quadrants
type: atomic
optional: true
display:
  level: key
  layer: overview
  title: 选区 Running 线程四象限
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: tid
    label: TID
    type: number
  - name: total_cpu_ms
    label: CPU 时间
    type: duration
    format: duration_ms
    unit: ms
  - name: q1_perf_running_ms
    label: Q1 性能核运行
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
  - name: q4a_io_blocked_ms
    label: Q4a 不可中断等待
    type: duration
    format: duration_ms
    unit: ms
  - name: q4b_sleeping_ms
    label: Q4b 睡眠等待
    type: duration
    format: duration_ms
    unit: ms
  - name: perf_core_pct
    label: 性能核占比
    type: percentage
    format: percentage
  - name: running_cpus
    label: 运行 CPU
    type: string
  - name: running_core_types
    label: 核心类型
    type: string
  - name: migrations
    label: 核迁移
    type: number
  - name: cross_cluster_migrations
    label: 跨簇迁移
    type: number
save_as: running_thread_quadrants
```
### Running 进程排名

- ID: `running_process_ranking`
- Type: `atomic`
- SQL: [`../sql/selection_range_cpu_sched_summary/running_process_ranking.sql`](../sql/selection_range_cpu_sched_summary/running_process_ranking.sql)

```yaml
id: running_process_ranking
type: atomic
optional: true
display:
  level: summary
  layer: list
  title: 选区 Running 进程排名
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: pid
    label: PID
    type: number
  - name: running_ms
    label: Running 时间
    type: duration
    format: duration_ms
    unit: ms
  - name: thread_count
    label: 线程数
    type: number
save_as: running_process_ranking
```
### 各核 duration-weighted 频率

- ID: `cpu_freq_by_core`
- Type: `atomic`
- SQL: [`../sql/selection_range_cpu_sched_summary/cpu_freq_by_core.sql`](../sql/selection_range_cpu_sched_summary/cpu_freq_by_core.sql)

```yaml
id: cpu_freq_by_core
type: atomic
optional: true
display:
  level: summary
  layer: list
  title: 选区各核平均频率
  columns:
  - name: cpu
    label: CPU
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: avg_freq_mhz
    label: 平均频率
    type: number
  - name: min_freq_mhz
    label: 最低频率
    type: number
  - name: max_freq_mhz
    label: 最高频率
    type: number
  - name: covered_ms
    label: 覆盖时长
    type: duration
    format: duration_ms
    unit: ms
save_as: cpu_freq_by_core
```
### 各核频率分布

- ID: `cpu_freq_distribution`
- Type: `atomic`
- SQL: [`../sql/selection_range_cpu_sched_summary/cpu_freq_distribution.sql`](../sql/selection_range_cpu_sched_summary/cpu_freq_distribution.sql)

```yaml
id: cpu_freq_distribution
type: atomic
optional: true
display:
  level: detail
  layer: deep
  title: 选区各核频率分布
  columns:
  - name: cpu
    label: CPU
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: freq_mhz_bucket
    label: 频率桶
    type: number
  - name: duration_ms
    label: 时长
    type: duration
    format: duration_ms
    unit: ms
  - name: pct_of_range
    label: 区间占比
    type: percentage
    format: percentage
save_as: cpu_freq_distribution
```
## Output and evidence contract

```yaml
format: structured
```
