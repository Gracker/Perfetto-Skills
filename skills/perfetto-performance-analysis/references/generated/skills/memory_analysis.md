GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/memory_analysis.skill.yaml
Source SHA-256: cdec84f3101148083ffa1b4e4d4fd0fd16bfcac16c0a71b257ca50f86c84311c
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# 内存性能分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: memory_analysis
version: '2.1'
type: composite
category: memory
tier: S
```

## Metadata

```yaml
display_name: 内存性能分析
description: 分析应用内存使用、GC 行为和潜在内存问题
icon: memory
tags:
- memory
- heap
- gc
- oom
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 内存
  - 堆内存
  - 内存泄漏
  - OOM
  - GC
  - 内存占用
  - 内存溢出
  en:
  - memory
  - heap
  - oom
  - gc
  - memory leak
  - allocation
  - rss
patterns:
- .*内存.*
- .*memory.*
- .*GC.*
- .*heap.*
```

## Prerequisites

```yaml
modules: []
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
- name: gc_count_critical
  type: number
  required: false
  default: 100
  description: GC 次数严重阈值
- name: gc_count_warning
  type: number
  required: false
  default: 50
  description: GC 次数警告阈值
- name: gc_total_time_critical_ms
  type: number
  required: false
  default: 2000
  description: GC 总耗时严重阈值（ms）
- name: main_thread_gc_critical
  type: number
  required: false
  default: 10
  description: 主线程 GC 次数严重阈值
- name: single_gc_warning_ms
  type: number
  required: false
  default: 50
  description: 单次 GC 告警阈值（ms）
```

## Ordered execution

### 获取目标进程

- ID: `get_process`
- Type: `atomic`
- SQL: [`../sql/memory_analysis/get_process.sql`](../sql/memory_analysis/get_process.sql)

```yaml
id: get_process
type: atomic
display:
  level: summary
  layer: overview
  title: 目标进程
  columns:
  - name: upid
    label: UPID
    type: number
  - name: pid
    label: PID
    type: number
  - name: process_name
    label: 进程名
    type: string
save_as: target_process
on_empty: 未找到目标进程
```
### 初始化 GC 事件视图

- ID: `init_gc_view`
- Type: `atomic`
- SQL: [`../sql/memory_analysis/init_gc_view.sql`](../sql/memory_analysis/init_gc_view.sql)

```yaml
id: init_gc_view
type: atomic
display:
  level: hidden
optional: true
condition: target_process.data.length > 0
```
### 检测 VSync 周期

- ID: `get_vsync_period`
- Type: `skill`

```yaml
id: get_vsync_period
type: skill
skill: vsync_period_detection
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: vsync_info
display:
  level: hidden
optional: true
```
### RSS/Swap 增长检测

- ID: `memory_growth_summary`
- Type: `skill`

```yaml
id: memory_growth_summary
type: skill
skill: memory_growth_detector
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: memory_growth_summary
display:
  level: summary
  layer: overview
  title: RSS/Swap 增长趋势
optional: true
```
### RSS/Swap 峰值

- ID: `rss_swap_peaks`
- Type: `skill`

```yaml
id: rss_swap_peaks
type: skill
skill: linux_process_rss_swap_timeline
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: rss_swap_peaks
display:
  level: summary
  layer: overview
  title: 进程 RSS/Swap 峰值
optional: true
```
### Heap Graph 总览

- ID: `heap_graph_summary`
- Type: `skill`

```yaml
id: heap_graph_summary
type: skill
skill: android_heap_graph_summary
params:
  process_name: ${package}
  max_rows: 30
save_as: heap_graph_summary
display:
  level: key
  layer: list
  title: Heap Graph 总览
optional: true
```
### Heap Graph 泄漏候选

- ID: `heap_graph_leak_candidates`
- Type: `skill`

```yaml
id: heap_graph_leak_candidates
type: skill
skill: android_heap_graph_leak_candidates
params:
  process_name: ${package}
  max_candidates: 20
  max_reference_edges: 50
save_as: heap_graph_leak_candidates
display:
  level: key
  layer: list
  title: Heap Graph 泄漏候选
optional: true
```
### Bitmap 内存

- ID: `bitmap_memory`
- Type: `skill`

```yaml
id: bitmap_memory
type: skill
skill: android_bitmap_memory_per_process
params:
  package: ${package}
save_as: bitmap_memory
display:
  level: detail
  layer: list
  title: Bitmap 内存
optional: true
```
### 全 Trace Native Heap 热点

- ID: `native_heap_hotspots`
- Type: `skill`

```yaml
id: native_heap_hotspots
type: skill
skill: native_heap_breakdown
params:
  min_size_mb: 1
  min_alloc_mb: 20
  max_rows: 100
save_as: native_heap_hotspots
display:
  level: detail
  layer: list
  title: 全 Trace Native Heap 保留/Churn 热点
optional: true
```
### LMK 事件

- ID: `lmk_events`
- Type: `skill`

```yaml
id: lmk_events
type: skill
skill: lmk_kill_attribution
params:
  process_name: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: lmk_events
display:
  level: detail
  layer: list
  title: LMK 事件
optional: true
```
### GC 概览

- ID: `gc_overview`
- Type: `atomic`
- SQL: [`../sql/memory_analysis/gc_overview.sql`](../sql/memory_analysis/gc_overview.sql)

```yaml
id: gc_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: total_gc_count
    label: GC 次数
  - key: total_gc_time_ms
    label: GC 总耗时
    format: '{{value}} ms'
  - key: main_thread_gc_count
    label: 主线程 GC
  - key: gc_frequency_rating
    label: 频率评级
  insights:
  - condition: total_gc_count > 100
    template: GC 频繁 ({{total_gc_count}} 次)，可能存在内存抖动
  - condition: main_thread_gc_time_ms > 500
    template: 主线程 GC 耗时 {{main_thread_gc_time_ms}}ms，影响流畅度
display:
  level: key
  layer: overview
  title: GC 总体情况
  columns:
  - name: total_gc_count
    label: GC 次数
    type: number
    format: compact
  - name: total_gc_time_ms
    label: GC 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_gc_time_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_gc_time_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: min_gc_time_ms
    label: 最小耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: main_thread_gc_count
    label: 主线程 GC
    type: number
    format: compact
  - name: main_thread_gc_time_ms
    label: 主线程 GC 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: gc_per_second
    label: GC 频率
    type: number
  - name: gc_frequency_rating
    label: 频率评级
    type: string
  - name: gc_time_rating
    label: 耗时评级
    type: string
save_as: gc_overview
condition: target_process.data.length > 0
```
### GC 事件统计

- ID: `gc_stats`
- Type: `atomic`
- SQL: [`../sql/memory_analysis/gc_stats.sql`](../sql/memory_analysis/gc_stats.sql)

```yaml
id: gc_stats
type: atomic
synthesize:
  role: list
  groupBy:
  - field: gc_type
    title: 按 GC 类型分布
  fields:
  - key: gc_type
    label: GC 类型
  - key: count
    label: 次数
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms'
display:
  level: key
  layer: overview
  title: GC 类型分布
  columns:
  - name: gc_type
    label: GC 类型
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
  - name: main_thread_count
    label: 主线程 GC
    type: number
    format: compact
save_as: gc_stats
condition: target_process.data.length > 0
```
### GC 与帧关联

- ID: `gc_frame_impact`
- Type: `atomic`
- SQL: [`../sql/memory_analysis/gc_frame_impact.sql`](../sql/memory_analysis/gc_frame_impact.sql)

```yaml
id: gc_frame_impact
type: atomic
synthesize:
  role: list
  groupBy:
  - field: impact
    title: 按影响类型分布
  fields:
  - key: gc_name
    label: GC 类型
  - key: gc_dur_ms
    label: GC 耗时
    format: '{{value}} ms'
  - key: impact
    label: 影响
optional: true
display:
  level: key
  layer: list
  title: GC 导致的掉帧分析
  columns:
  - name: gc_name
    label: GC 类型
    type: string
  - name: gc_dur_ms
    label: GC 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: jank_type
    label: 掉帧类型
    type: string
  - name: frame_dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: impact
    label: 影响
    type: string
save_as: gc_frame_impact
condition: target_process.data.length > 0
```
### 主线程 GC

- ID: `main_thread_gc`
- Type: `atomic`
- SQL: [`../sql/memory_analysis/main_thread_gc.sql`](../sql/memory_analysis/main_thread_gc.sql)

```yaml
id: main_thread_gc
type: atomic
display:
  level: key
  layer: list
  title: 主线程 GC (可能导致掉帧)
  columns:
  - name: gc_type
    label: GC 类型
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: ts_str
    label: 时间
    type: timestamp
    clickAction: navigate_range
    durationColumn: dur_str
  - name: dur_str
    label: 持续时间(ns)
    type: duration
    format: duration_ms
    unit: ns
    hidden: true
  - name: severity
    label: 严重程度
    type: enum
  - name: dropped_frames
    label: 掉帧数
    type: number
save_as: main_thread_gc
condition: target_process.data.length > 0
```
### GC 期间主线程状态

- ID: `gc_thread_state`
- Type: `atomic`
- SQL: [`../sql/memory_analysis/gc_thread_state.sql`](../sql/memory_analysis/gc_thread_state.sql)

```yaml
id: gc_thread_state
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: GC 期间主线程状态分析
  columns:
  - name: gc_type
    label: GC 类型
    type: string
  - name: gc_dur_ms
    label: GC 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: state
    label: 线程状态
    type: string
  - name: state_dur_ms
    label: 状态耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: blocked_function
    label: 阻塞函数
    type: string
save_as: gc_thread_state
condition: target_process.data.length > 0
```
### GC 间隔分析

- ID: `gc_interval_analysis`
- Type: `atomic`
- SQL: [`../sql/memory_analysis/gc_interval_analysis.sql`](../sql/memory_analysis/gc_interval_analysis.sql)

```yaml
id: gc_interval_analysis
type: atomic
display:
  level: detail
  layer: list
  title: GC 间隔分析（内存抖动检测）
  columns:
  - name: interval_bucket
    label: 间隔分段
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: avg_interval_ms
    label: 平均间隔
    type: duration
    format: duration_ms
    unit: ms
  - name: min_interval_ms
    label: 最小间隔
    type: duration
    format: duration_ms
    unit: ms
save_as: gc_intervals
condition: target_process.data.length > 0
```
### 长时间 GC

- ID: `long_gc_events`
- Type: `atomic`
- SQL: [`../sql/memory_analysis/long_gc_events.sql`](../sql/memory_analysis/long_gc_events.sql)

```yaml
id: long_gc_events
type: atomic
display:
  level: key
  layer: list
  title: 耗时最长的 GC 事件
  columns:
  - name: gc_type
    label: GC 类型
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: thread_name
    label: 线程
    type: string
  - name: ts_str
    label: 时间
    type: timestamp
    clickAction: navigate_range
    durationColumn: dur_str
  - name: dur_str
    label: 持续时间(ns)
    type: duration
    format: duration_ms
    unit: ns
    hidden: true
  - name: is_main_thread
    label: 主线程
    type: string
save_as: long_gc
condition: target_process.data.length > 0
```
### 内存诊断

- ID: `memory_diagnosis`
- Type: `diagnostic`

```yaml
id: memory_diagnosis
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
  - template: 内存诊断：{{diagnosis}}
display:
  level: key
  layer: overview
  title: 问题诊断
inputs:
- gc_overview
- gc_stats
- main_thread_gc
- long_gc
- gc_intervals
rules:
- condition: gc_overview.data[0]?.total_gc_count > (inputs?.gc_count_critical ?? 100)
  severity: critical
  diagnosis: GC 频率过高 (${gc_overview.data[0].total_gc_count} 次)
  confidence: high
  suggestions:
  - 检查是否有频繁的对象创建和销毁
  - 使用对象池重用对象
  - 避免在循环中创建对象
- condition: gc_overview.data[0]?.total_gc_count > (inputs?.gc_count_warning ?? 50)
  severity: warning
  diagnosis: GC 频率较高 (${gc_overview.data[0].total_gc_count} 次)
  confidence: medium
  suggestions:
  - 检查内存分配热点
  - 优化临时对象使用
- condition: gc_overview.data[0]?.total_gc_time_ms > (inputs?.gc_total_time_critical_ms ?? 2000)
  severity: critical
  diagnosis: GC 总耗时过长 (${gc_overview.data[0].total_gc_time_ms}ms)
  confidence: high
  suggestions:
  - 减少内存分配频率
  - 检查大对象分配
  - 考虑调整堆大小
- condition: gc_overview.data[0]?.main_thread_gc_count > (inputs?.main_thread_gc_critical ?? 10)
  severity: critical
  diagnosis: 主线程发生 ${gc_overview.data[0].main_thread_gc_count} 次 GC
  confidence: high
  suggestions:
  - 将内存密集型操作移到后台线程
  - 避免在 UI 线程分配大量内存
- condition: long_gc.data[0]?.dur_ms > (inputs?.single_gc_warning_ms ?? 50)
  severity: warning
  diagnosis: 单次 GC 暂停过长 (${long_gc.data[0].dur_ms}ms)
  confidence: medium
  suggestions:
  - 检查大对象分配
  - 考虑调整堆大小
- condition: gc_intervals.data.find(i => i.interval_bucket === '<100ms (频繁)')?.count > 10
  severity: critical
  diagnosis: 检测到内存抖动（GC 间隔 <100ms）
  confidence: high
  suggestions:
  - 检查是否有频繁的对象创建销毁
  - 使用 Memory Profiler 分析分配热点
  - 考虑使用对象池
```
## Output and evidence contract

```yaml
format: structured
```
