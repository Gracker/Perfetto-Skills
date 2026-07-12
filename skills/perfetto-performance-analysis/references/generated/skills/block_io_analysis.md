GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/block_io_analysis.skill.yaml
Source SHA-256: 6694949cda0a83aa4448782fcdc7b6b7fb8c62134598018d5f702eb571a23985
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# Block I/O 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: block_io_analysis
version: '3.0'
type: composite
category: io
tier: S
```

## Metadata

```yaml
display_name: Block I/O 分析
description: 分析块设备 I/O 操作和线程阻塞（D 状态）
icon: storage
tags:
- io
- block
- disk
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - IO
  - 磁盘
  - 存储
  - 块设备
  - 读写
  - IO延迟
  - IO等待
  - IO阻塞
  - D状态
  en:
  - IO
  - disk
  - storage
  - block device
  - read write
  - IO latency
  - IO wait
  - block IO
patterns:
- .*(IO|I/O).*
- .*磁盘.*
- .*块设备.*
- .*block.?io.*
```

## Prerequisites

```yaml
required_tables:
- thread_state
modules:
- linux.block_io
```

## Inputs

```yaml
- name: device
  type: string
  required: false
  description: 设备名过滤
- name: min_queue_depth
  type: number
  required: false
  default: 5
  description: 最小队列深度阈值
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
- SQL: [`../sql/block_io_analysis/data_check.sql`](../sql/block_io_analysis/data_check.sql)

```yaml
id: data_check
type: atomic
display: false
save_as: data_check
```
### IO 操作概览

- ID: `io_overview`
- Type: `atomic`
- SQL: [`../sql/block_io_analysis/io_overview.sql`](../sql/block_io_analysis/io_overview.sql)

```yaml
id: io_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: io_type
    label: IO 类型
  - key: operation_count
    label: 操作次数
  - key: avg_dur_ms
    label: 平均耗时
    format: '{{value}} ms'
  - key: max_dur_ms
    label: 最大耗时
    format: '{{value}} ms'
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms'
  insights:
  - condition: avg_dur_ms > 50
    template: 平均 IO 耗时 {{avg_dur_ms}}ms，存在严重 IO 瓶颈
  - condition: avg_dur_ms > 10
    template: 平均 IO 耗时 {{avg_dur_ms}}ms，IO 性能需关注
  - condition: max_dur_ms > 500
    template: 最大 IO 耗时 {{max_dur_ms}}ms，存在极端慢 IO
display:
  level: summary
  layer: overview
  title: IO 操作概览
  columns:
  - name: io_type
    label: IO 类型
    type: string
  - name: operation_count
    label: 操作次数
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
save_as: io_overview
optional: true
condition: data_check.data[0]?.has_data === 1
```
### 设备级 IO 统计

- ID: `device_io_stats`
- Type: `atomic`
- SQL: [`../sql/block_io_analysis/device_io_stats.sql`](../sql/block_io_analysis/device_io_stats.sql)

```yaml
id: device_io_stats
type: atomic
display:
  level: summary
  layer: overview
  title: 设备级 IO 统计
  columns:
  - name: dev
    label: 设备
    type: string
  - name: io_count
    label: IO 次数
    type: number
    format: compact
  - name: total_io_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_io_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_io_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
save_as: device_io_stats
optional: true
condition: data_check.data[0]?.has_data === 1
```
### IO 队列深度

- ID: `io_queue_depth`
- Type: `atomic`
- SQL: [`../sql/block_io_analysis/io_queue_depth.sql`](../sql/block_io_analysis/io_queue_depth.sql)

```yaml
id: io_queue_depth
type: atomic
display:
  level: detail
  layer: overview
  title: IO 队列深度
  columns:
  - name: dev
    label: 设备
    type: string
  - name: max_queue_depth
    label: 最大队列深度
    type: number
    format: compact
  - name: avg_queue_depth
    label: 平均队列深度
    type: number
    format: compact
save_as: io_queue_depth
optional: true
condition: data_check.data[0]?.has_data === 1
```
### 高队列深度时段

- ID: `high_queue_periods`
- Type: `atomic`
- SQL: [`../sql/block_io_analysis/high_queue_periods.sql`](../sql/block_io_analysis/high_queue_periods.sql)

```yaml
id: high_queue_periods
type: atomic
display:
  level: detail
  layer: list
  title: 高队列深度时段
  columns:
  - name: ts
    label: 时间戳
    type: timestamp
    clickAction: navigate_timeline
  - name: dev
    label: 设备
    type: string
  - name: queue_depth
    label: 队列深度
    type: number
    format: compact
save_as: high_queue_periods
optional: true
condition: data_check.data[0]?.has_data === 1
```
### 长耗时 IO

- ID: `long_io_operations`
- Type: `atomic`
- SQL: [`../sql/block_io_analysis/long_io_operations.sql`](../sql/block_io_analysis/long_io_operations.sql)

```yaml
id: long_io_operations
type: atomic
display:
  level: detail
  layer: list
  title: 长耗时 IO 操作 (>10ms)
  columns:
  - name: ts
    label: 时间戳
    type: timestamp
    clickAction: navigate_timeline
  - name: io_type
    label: IO 类型
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: dev
    label: 设备
    type: string
save_as: long_io_operations
optional: true
condition: data_check.data[0]?.has_data === 1
```
### IO/page-cache 候选线程分析

- ID: `io_thread_blocking`
- Type: `atomic`
- SQL: [`../sql/block_io_analysis/io_thread_blocking.sql`](../sql/block_io_analysis/io_thread_blocking.sql)

```yaml
id: io_thread_blocking
type: atomic
display:
  level: detail
  layer: list
  title: IO/page-cache 等待候选线程
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: io_wait
    label: io_wait
    type: boolean
  - name: evidence_strength
    label: 证据强度
    type: string
  - name: block_count
    label: 阻塞次数
    type: number
    format: compact
  - name: total_blocked_ms
    label: 总阻塞时间
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_blocked_ms
    label: 平均阻塞时间
    type: duration
    format: duration_ms
    unit: ms
save_as: io_thread_blocking
optional: true
condition: data_check.data[0]?.has_data === 1
```
### 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/block_io_analysis/root_cause_classification.sql`](../sql/block_io_analysis/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
optional: true
synthesize:
  role: conclusion
  fields:
  - key: category
    label: 诊断类别
  - key: severity
    label: 严重程度
  - key: description
    label: 描述
  - key: evidence
    label: 依据
  insights:
  - condition: severity === 'critical'
    template: IO 瓶颈严重：{{description}}（{{evidence}}）
  - condition: severity === 'warning'
    template: IO 风险：{{description}}（{{evidence}}）
display:
  level: summary
  layer: diagnosis
  title: IO 诊断
  columns:
  - name: category
    label: 诊断类别
    type: string
  - name: severity
    label: 严重程度
    type: string
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
