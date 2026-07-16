GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/dmabuf_analysis.skill.yaml
Source SHA-256: 82544957bb27c764d3304e2acc9a3306fa7fab10dc9b095bcfe0cae0798b53f6
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# DMA-BUF 内存分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: dmabuf_analysis
version: '3.0'
type: composite
category: memory
tier: S
```

## Metadata

```yaml
display_name: DMA-BUF 内存分析
description: 分析图形内存 (DMA-BUF) 使用情况和潜在泄漏
icon: image
tags:
- memory
- dmabuf
- graphics
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - DMA
  - dmabuf
  - 图形内存
  - gralloc
  - 缓冲区
  - 显示内存
  - GPU内存
  - 图形缓冲
  en:
  - DMA
  - dmabuf
  - dma buffer
  - graphics memory
  - gralloc
  - buffer
  - display memory
  - GPU memory
patterns:
- .*[Dd][Mm][Aa].*
- .*dmabuf.*
- .*gralloc.*
- .*图形内存.*
```

## Prerequisites

```yaml
optional_tables:
- ion_heap_graph
modules:
- android.memory.dmabuf
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标应用包名（支持 GLOB），留空分析所有 DMA Buffer
- name: min_size_mb
  type: number
  required: false
  default: 1
  description: 最小缓冲区大小阈值 (MB)
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
- SQL: [`../sql/dmabuf_analysis/data_check.sql`](../sql/dmabuf_analysis/data_check.sql)

```yaml
id: data_check
type: atomic
optional: true
display: false
save_as: data_check
```
### DMA Buffer 概览

- ID: `dmabuf_overview`
- Type: `atomic`
- SQL: [`../sql/dmabuf_analysis/dmabuf_overview.sql`](../sql/dmabuf_analysis/dmabuf_overview.sql)

```yaml
id: dmabuf_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: process_name
    label: 进程名
  - key: alloc_count
    label: 分配次数
  - key: total_alloc_mb
    label: 总分配量
    format: '{{value}} MB'
  - key: net_alloc_mb
    label: 净分配量
    format: '{{value}} MB'
  - key: max_single_alloc_mb
    label: 最大单次分配
    format: '{{value}} MB'
  insights:
  - condition: net_alloc_mb > 200
    template: 净分配量 {{net_alloc_mb}}MB，可能存在 Buffer 未释放
  - condition: net_alloc_mb > 500
    template: 净分配量 {{net_alloc_mb}}MB，DMA-BUF 内存压力严重
  - condition: max_single_alloc_mb > 50
    template: 单次最大分配 {{max_single_alloc_mb}}MB，存在大型 Buffer 分配
display:
  level: summary
  layer: overview
  title: DMA Buffer 概览
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: alloc_count
    label: 分配次数
    type: number
    format: compact
  - name: total_alloc_mb
    label: 总分配(MB)
    type: number
    format: compact
  - name: total_free_mb
    label: 总释放(MB)
    type: number
    format: compact
  - name: net_alloc_mb
    label: 净分配(MB)
    type: number
    format: compact
  - name: max_single_alloc_mb
    label: 最大单次(MB)
    type: number
    format: compact
save_as: dmabuf_overview
condition: data_check.data[0]?.has_data === 1
```
### DMA Buffer 累积使用

- ID: `dmabuf_cumulative`
- Type: `atomic`
- SQL: [`../sql/dmabuf_analysis/dmabuf_cumulative.sql`](../sql/dmabuf_analysis/dmabuf_cumulative.sql)

```yaml
id: dmabuf_cumulative
type: atomic
optional: true
display:
  level: summary
  layer: overview
  title: DMA Buffer 累积使用量
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: current_mb
    label: 当前用量(MB)
    type: number
    format: compact
  - name: peak_mb
    label: 峰值用量(MB)
    type: number
    format: compact
save_as: dmabuf_cumulative
condition: data_check.data[0]?.has_data === 1
```
### 大型 Buffer 分配

- ID: `large_buffer_allocs`
- Type: `atomic`
- SQL: [`../sql/dmabuf_analysis/large_buffer_allocs.sql`](../sql/dmabuf_analysis/large_buffer_allocs.sql)

```yaml
id: large_buffer_allocs
type: atomic
display:
  level: detail
  layer: list
  title: 大型 DMA Buffer 分配
  columns:
  - name: ts
    label: 时间戳
    type: timestamp
    clickAction: navigate_timeline
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: size_mb
    label: 大小(MB)
    type: number
    format: compact
  - name: inode
    label: Inode
    type: number
save_as: large_buffer_allocs
condition: data_check.data[0]?.has_data === 1
```
### Buffer 分配频率

- ID: `dmabuf_frequency`
- Type: `atomic`
- SQL: [`../sql/dmabuf_analysis/dmabuf_frequency.sql`](../sql/dmabuf_analysis/dmabuf_frequency.sql)

```yaml
id: dmabuf_frequency
type: atomic
display:
  level: detail
  layer: list
  title: DMA Buffer 分配频率（按秒）
  columns:
  - name: time_sec
    label: 时间(秒)
    type: number
    format: compact
  - name: alloc_count
    label: 分配次数
    type: number
    format: compact
  - name: free_count
    label: 释放次数
    type: number
    format: compact
  - name: alloc_mb
    label: 分配量(MB)
    type: number
    format: compact
  - name: free_mb
    label: 释放量(MB)
    type: number
    format: compact
save_as: dmabuf_frequency
condition: data_check.data[0]?.has_data === 1
```
### 线程级分配统计

- ID: `thread_alloc_stats`
- Type: `atomic`
- SQL: [`../sql/dmabuf_analysis/thread_alloc_stats.sql`](../sql/dmabuf_analysis/thread_alloc_stats.sql)

```yaml
id: thread_alloc_stats
type: atomic
display:
  level: detail
  layer: list
  title: 线程级 DMA Buffer 分配
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: alloc_count
    label: 分配次数
    type: number
    format: compact
  - name: total_alloc_mb
    label: 总分配(MB)
    type: number
    format: compact
save_as: thread_alloc_stats
condition: data_check.data[0]?.has_data === 1
```
### Buffer 生命周期

- ID: `buffer_lifecycle`
- Type: `atomic`
- SQL: [`../sql/dmabuf_analysis/buffer_lifecycle.sql`](../sql/dmabuf_analysis/buffer_lifecycle.sql)

```yaml
id: buffer_lifecycle
type: atomic
synthesize:
  role: overview
  fields:
  - key: process_name
    label: 进程名
  - key: buffer_count
    label: Buffer 总数
  - key: freed_count
    label: 已释放
  - key: not_freed_count
    label: 未释放
  - key: avg_lifetime_sec
    label: 平均生命周期
    format: '{{value}} s'
  insights:
  - condition: not_freed_count > buffer_count * 0.3
    template: 未释放 Buffer 占比超 30%（{{not_freed_count}}/{{buffer_count}}），可能存在内存泄漏
  - condition: not_freed_count > 50
    template: '{{not_freed_count}} 个 Buffer 未释放，内存泄漏风险高'
  - condition: avg_lifetime_sec > 60
    template: 平均 Buffer 生命周期 {{avg_lifetime_sec}}s，Buffer 持有时间过长
display:
  level: detail
  layer: list
  title: Buffer 生命周期（泄漏检测）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: buffer_count
    label: Buffer 总数
    type: number
    format: compact
  - name: freed_count
    label: 已释放
    type: number
    format: compact
  - name: not_freed_count
    label: 未释放
    type: number
    format: compact
  - name: avg_lifetime_sec
    label: 平均生命周期(s)
    type: number
    format: compact
  - name: max_lifetime_sec
    label: 最大生命周期(s)
    type: number
    format: compact
save_as: buffer_lifecycle
condition: data_check.data[0]?.has_data === 1
```
### 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/dmabuf_analysis/root_cause_classification.sql`](../sql/dmabuf_analysis/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
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
  - template: DMA-BUF 诊断：{{category}} - {{description}}
display:
  level: summary
  layer: diagnosis
  title: DMA-BUF 诊断
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
condition: data_check.data[0]?.has_data === 1
```
## Output and evidence contract

```yaml
format: structured
```
