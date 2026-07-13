GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/gc_analysis.skill.yaml
Source SHA-256: 9953952ad063229e1a5f04d58a41962bce74d74d1c303ca177cb7055c0afb366
Source commit: 68b113e0355716255af357e8396cd71c71e11d97
# GC 行为分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gc_analysis
version: '3.0'
type: composite
category: memory
tier: S
```

## Metadata

```yaml
display_name: GC 行为分析
description: 深入分析垃圾回收行为和影响
icon: delete_sweep
tags:
- gc
- memory
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - GC
  - 垃圾回收
  - 内存回收
  - GC卡顿
  - GC暂停
  - 堆内存
  - 内存抖动
  en:
  - gc
  - garbage collection
  - gc pause
  - gc jank
  - heap
  - memory churn
patterns:
- .*GC.*
- .*gc.*
- .*垃圾回收.*
- .*garbage.*collection.*
```

## Prerequisites

```yaml
required_tables:
- slice
modules:
- android.garbage_collection
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标应用包名（支持 GLOB），留空分析所有 GC 事件
- name: min_gc_dur_ms
  type: number
  required: false
  default: 5
  description: 最小 GC 时长阈值 (毫秒)
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
```

## Ordered execution

### 数据检测

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/gc_analysis/data_check.sql`](../sql/gc_analysis/data_check.sql)

```yaml
id: data_check
type: atomic
optional: true
display: false
save_as: data_check
```
### GC 概览

- ID: `gc_overview`
- Type: `atomic`
- SQL: [`../sql/gc_analysis/gc_overview.sql`](../sql/gc_analysis/gc_overview.sql)

```yaml
id: gc_overview
type: atomic
condition: data_check.data[0]?.has_data === 1
synthesize:
  role: overview
  fields:
  - key: gc_type
    label: GC 类型
  - key: gc_count
    label: GC 次数
  - key: total_gc_dur_ms
    label: 总耗时
    format: '{{value}} ms'
  - key: avg_gc_dur_ms
    label: 平均耗时
    format: '{{value}} ms'
  - key: total_reclaimed_mb
    label: 回收内存
    format: '{{value}} MB'
  insights:
  - condition: gc_count > 50
    template: '{{gc_type}} 类型 GC 频繁 ({{gc_count}} 次)，可能存在内存抖动'
  - condition: total_gc_dur_ms > 500
    template: '{{gc_type}} GC 总耗时 {{total_gc_dur_ms}}ms，影响应用性能'
  - condition: gc_type === 'alloc' && gc_count > 20
    template: 分配触发 GC {{gc_count}} 次，内存分配速率过快
  - condition: gc_type === 'explicit' && gc_count > 5
    template: 显式 GC 调用 {{gc_count}} 次，检查是否有 System.gc()
display:
  level: summary
  layer: overview
  title: GC 概览
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: gc_type
    label: GC 类型
    type: string
  - name: is_mark_compact
    label: 标记整理
    type: number
  - name: gc_count
    label: 次数
    type: number
    format: compact
  - name: total_gc_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_gc_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_gc_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: total_reclaimed_mb
    label: 回收总量
    type: number
    format: compact
  - name: avg_reclaimed_mb
    label: 平均回收
    type: number
    format: compact
save_as: gc_overview
```
### GC 耗时分解

- ID: `gc_time_breakdown`
- Type: `atomic`
- SQL: [`../sql/gc_analysis/gc_time_breakdown.sql`](../sql/gc_analysis/gc_time_breakdown.sql)

```yaml
id: gc_time_breakdown
type: atomic
condition: data_check.data[0]?.has_data === 1
display:
  level: summary
  layer: overview
  title: GC 耗时分解
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: gc_type
    label: GC 类型
    type: string
  - name: gc_count
    label: 次数
    type: number
    format: compact
  - name: total_running_ms
    label: CPU 运行
    type: duration
    format: duration_ms
    unit: ms
  - name: total_runnable_ms
    label: 等待调度
    type: duration
    format: duration_ms
    unit: ms
  - name: total_io_wait_ms
    label: IO 等待
    type: duration
    format: duration_ms
    unit: ms
  - name: total_kernel_wait_ms
    label: 内核等待
    type: duration
    format: duration_ms
    unit: ms
  - name: total_sleep_ms
    label: 睡眠
    type: duration
    format: duration_ms
    unit: ms
  - name: total_wall_ms
    label: Wall 时间
    type: duration
    format: duration_ms
    unit: ms
save_as: gc_time_breakdown
```
### 长耗时 GC 事件

- ID: `long_gc_events`
- Type: `atomic`
- SQL: [`../sql/gc_analysis/long_gc_events.sql`](../sql/gc_analysis/long_gc_events.sql)

```yaml
id: long_gc_events
type: atomic
condition: data_check.data[0]?.has_long_gc === 1
display:
  level: detail
  layer: list
  title: 长耗时 GC 事件
  columns:
  - name: gc_ts_nav
    label: 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: gc_type
    label: GC 类型
    type: string
  - name: gc_dur_ms
    label: 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: running_ms
    label: CPU 运行
    type: duration
    format: duration_ms
    unit: ms
  - name: runnable_ms
    label: 等待调度
    type: duration
    format: duration_ms
    unit: ms
  - name: reclaimed_mb
    label: 回收
    type: number
    format: compact
  - name: max_heap_mb
    label: 最大堆
    type: number
    format: compact
  - name: min_heap_mb
    label: 最小堆
    type: number
    format: compact
save_as: long_gc_events
```
### GC 对帧的影响

- ID: `gc_frame_impact`
- Type: `atomic`
- SQL: [`../sql/gc_analysis/gc_frame_impact.sql`](../sql/gc_analysis/gc_frame_impact.sql)

```yaml
id: gc_frame_impact
type: atomic
optional: true
condition: data_check.data[0]?.has_data === 1
display:
  level: detail
  layer: list
  title: GC 对帧的影响
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: jank_type
    label: Jank 类型
    type: string
  - name: frame_count
    label: 受影响帧数
    type: number
    format: compact
save_as: gc_frame_impact
```
### 进程 GC 统计

- ID: `process_gc_stats`
- Type: `atomic`
- SQL: [`../sql/gc_analysis/process_gc_stats.sql`](../sql/gc_analysis/process_gc_stats.sql)

```yaml
id: process_gc_stats
type: atomic
optional: true
condition: data_check.data[0]?.has_process_stats === 1
synthesize:
  role: overview
  fields:
  - key: process_name
    label: 进程
  - key: heap_size_mb
    label: 堆大小
    format: '{{value}} MB'
  - key: alloc_rate_mb_per_sec
    label: 分配速率
    format: '{{value}} MB/s'
  - key: gc_cpu_pct
    label: GC CPU 占比
    format: '{{value}}%'
  - key: gc_running_efficiency
    label: GC 效率
  insights:
  - condition: gc_cpu_pct > 15
    template: 进程 {{process_name}} GC CPU 占比 {{gc_cpu_pct}}%，严重影响性能
  - condition: gc_cpu_pct > 5
    template: 进程 {{process_name}} GC CPU 占比 {{gc_cpu_pct}}%，需关注
  - condition: heap_utilization > 0.9
    template: 堆利用率 {{heap_utilization}}，内存压力大
  - condition: alloc_rate_mb_per_sec > 50
    template: 内存分配速率 {{alloc_rate_mb_per_sec}} MB/s，分配过快
display:
  level: detail
  layer: list
  title: 进程 GC 统计
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: heap_size_mb
    label: 堆大小
    type: bytes
    format: compact
  - name: alloc_rate_mb_per_sec
    label: 分配速率 (MB/s)
    type: number
    format: compact
  - name: heap_utilization
    label: 堆利用率
    type: percentage
    format: percentage
  - name: gc_cpu_sec
    label: GC CPU 时间
    type: duration
    format: duration_ms
  - name: gc_cpu_pct
    label: GC CPU 占比
    type: percentage
    format: percentage
  - name: gc_running_efficiency
    label: GC 效率
    type: number
    format: compact
save_as: process_gc_stats
```
### GC 频率分析

- ID: `gc_frequency`
- Type: `atomic`
- SQL: [`../sql/gc_analysis/gc_frequency.sql`](../sql/gc_analysis/gc_frequency.sql)

```yaml
id: gc_frequency
type: atomic
condition: data_check.data[0]?.has_data === 1
display:
  level: detail
  layer: list
  title: GC 频率分析（每秒）
  columns:
  - name: time_sec
    label: 时间 (秒)
    type: number
    format: compact
  - name: gc_count
    label: GC 次数
    type: number
    format: compact
  - name: gc_dur_ms
    label: GC 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: reclaimed_mb
    label: 回收量
    type: number
    format: compact
save_as: gc_frequency
```
### 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/gc_analysis/root_cause_classification.sql`](../sql/gc_analysis/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
optional: true
condition: data_check.data[0]?.has_data === 1
synthesize:
  role: conclusion
  fields:
  - key: category
    label: 诊断类别
  - key: severity
    label: 严重程度
  - key: description
    label: 描述
  insights:
  - template: GC 诊断：{{category}} - {{description}}
display:
  level: summary
  layer: diagnosis
  title: GC 诊断
  columns:
  - name: category
    label: 诊断类别
    type: enum
  - name: severity
    label: 严重程度
    type: enum
  - name: description
    label: 描述
    type: string
  - name: evidence
    label: 依据
    type: string
save_as: root_cause
```
## Output and evidence contract

```yaml
format: structured
```
