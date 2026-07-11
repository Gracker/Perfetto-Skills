GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/io_pressure.skill.yaml
Source SHA-256: 0a450c93ae1f945c82729a14f132f2006df7bf395e1ffa1fd86ae69180fa5a23
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# IO 压力分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: io_pressure
version: '3.0'
type: composite
category: io
tier: S
```

## Metadata

```yaml
display_name: IO 压力分析
description: 从系统层面分析 IO 压力和瓶颈
icon: storage
tags:
- io
- pressure
- disk
- system
```

## Triggers

```yaml
keywords:
  zh:
  - IO等待
  - IO压力
  - 存储
  - 读写
  - 阻塞
  - iowait
  - 磁盘
  en:
  - io wait
  - io pressure
  - storage
  - read write
  - blocking
  - iowait
  - disk
patterns:
- .*IO.*
- .*io.*wait.*
- .*存储.*
- .*磁盘.*
- .*读写.*
```

## Prerequisites

```yaml
required_tables:
- thread_state
modules:
- sched
- linux.threads
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
- name: min_duration_ms
  type: number
  required: false
  default: 1
  description: 最小 IO Wait 时长阈值（毫秒）
- name: max_items
  type: number
  required: false
  default: 20
  description: 列表最大返回条数
- name: long_io_threshold_ms
  type: number
  required: false
  default: 10
  description: 长 IO 事件阈值（毫秒）
- name: critical_io_wait_ms
  type: number
  required: false
  default: 5000
  description: IO Wait 严重阈值（毫秒，总等待时间超过此值为 critical）
- name: warning_io_wait_ms
  type: number
  required: false
  default: 1000
  description: IO Wait 警告阈值（毫秒，总等待时间超过此值为 warning）
```

## Ordered execution

### 数据检测

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/io_pressure/data_check.sql`](../sql/io_pressure/data_check.sql)

```yaml
id: data_check
type: atomic
display: false
save_as: data_check
```
### IO Wait 总览

- ID: `io_wait_overview`
- Type: `atomic`
- SQL: [`../sql/io_pressure/io_wait_overview.sql`](../sql/io_pressure/io_wait_overview.sql)

```yaml
id: io_wait_overview
type: atomic
optional: true
condition: data_check.data[0]?.has_data === 1
synthesize:
  role: overview
  fields:
  - key: io_wait_events
    label: IO Wait 事件数
  - key: total_io_wait_ms
    label: 总 IO Wait 时间
    format: duration_ms
  - key: avg_io_wait_ms
    label: 平均 IO Wait
    format: duration_ms
  - key: max_io_wait_ms
    label: 最大 IO Wait
    format: duration_ms
  - key: affected_threads
    label: 受影响线程数
  - key: severity
    label: 严重度
  insights:
  - condition: severity === 'critical'
    template: ⚠️ IO 压力严重：总等待 {{total_io_wait_ms}}ms，影响 {{affected_threads}} 个线程
  - condition: severity === 'warning'
    template: ⚠ IO 压力偏高：总等待 {{total_io_wait_ms}}ms
  - condition: severity === 'info' || severity === 'normal'
    template: IO 压力正常：总等待 {{total_io_wait_ms}}ms
display:
  level: summary
  layer: overview
  title: IO 等待概览
  columns:
  - name: io_wait_events
    label: IO Wait 事件数
    type: number
    format: compact
  - name: total_io_wait_ms
    label: 总 IO Wait
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_io_wait_ms
    label: 平均 IO Wait
    type: duration
    format: duration_ms
    unit: ms
  - name: max_io_wait_ms
    label: 最大 IO Wait
    type: duration
    format: duration_ms
    unit: ms
  - name: affected_threads
    label: 受影响线程数
    type: number
    format: compact
  - name: severity
    label: 严重度
    type: string
save_as: io_overview
```
### 进程 IO Wait 分布

- ID: `process_io_distribution`
- Type: `atomic`
- SQL: [`../sql/io_pressure/process_io_distribution.sql`](../sql/io_pressure/process_io_distribution.sql)

```yaml
id: process_io_distribution
type: atomic
optional: true
condition: data_check.data[0]?.has_data === 1
synthesize:
  role: list
  fields:
  - key: process_name
    label: 进程名
  - key: io_wait_ms
    label: IO Wait 时间
    format: duration_ms
  - key: pct_of_total
    label: 占比
    format: percentage
  insights:
  - condition: pct_of_total > 50
    template: ⚠️ {{process_name}} 占 IO Wait 的 {{pct_of_total}}%，是主要 IO 消费者
display:
  level: detail
  layer: list
  title: 进程 IO 等待排行
  columns:
  - name: process_name
    label: 进程名
    type: string
  - name: pid
    label: PID
    type: number
  - name: io_wait_ms
    label: IO Wait(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: io_events
    label: 事件数
    type: number
  - name: avg_wait_ms
    label: 平均(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: pct_of_total
    label: 占比(%)
    type: percentage
save_as: process_io
```
### 阻塞函数热点

- ID: `blocking_functions`
- Type: `atomic`
- SQL: [`../sql/io_pressure/blocking_functions.sql`](../sql/io_pressure/blocking_functions.sql)

```yaml
id: blocking_functions
type: atomic
condition: data_check.data[0]?.has_blocked_functions === 1
optional: true
synthesize:
  role: list
  fields:
  - key: blocked_function
    label: 阻塞函数
  - key: total_block_ms
    label: 总阻塞时间
    format: duration_ms
  - key: block_count
    label: 次数
  insights:
  - condition: blocked_function.includes('f2fs') || blocked_function.includes('ext4')
    template: '文件系统阻塞: {{blocked_function}} 累计 {{total_block_ms}}ms'
display:
  level: detail
  layer: list
  title: IO/page-cache 候选函数排行
  columns:
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: block_count
    label: 次数
    type: number
  - name: total_block_ms
    label: 总阻塞(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_block_ms
    label: 平均(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: max_block_ms
    label: 最大(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: category
    label: 分类
    type: string
save_as: blocking_functions
```
### 线程 IO Wait 详情

- ID: `thread_io_details`
- Type: `atomic`
- SQL: [`../sql/io_pressure/thread_io_details.sql`](../sql/io_pressure/thread_io_details.sql)

```yaml
id: thread_io_details
type: atomic
condition: data_check.data[0]?.has_data === 1
optional: true
display:
  level: detail
  layer: list
  title: 线程级 IO 等待
  columns:
  - name: thread_name
    label: 线程名
    type: string
  - name: tid
    label: TID
    type: number
  - name: process_name
    label: 进程
    type: string
  - name: io_wait_ms
    label: IO Wait(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: io_events
    label: 事件数
    type: number
  - name: max_wait_ms
    label: 最大(ms)
    type: duration
    format: duration_ms
    unit: ms
save_as: thread_io
```
### 长 IO Wait 事件

- ID: `long_io_events`
- Type: `atomic`
- SQL: [`../sql/io_pressure/long_io_events.sql`](../sql/io_pressure/long_io_events.sql)

```yaml
id: long_io_events
type: atomic
condition: data_check.data[0]?.has_long_io === 1
optional: true
display:
  level: detail
  layer: deep
  title: 长时间 IO/page-cache 候选事件
  columns:
  - name: ts
    label: 时间戳
    type: timestamp
    clickAction: navigate_timeline
  - name: duration_ms
    label: 时长(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: thread_name
    label: 线程
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
save_as: long_io_events
```
### IO 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/io_pressure/root_cause_classification.sql`](../sql/io_pressure/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
optional: true
condition: data_check.data[0]?.has_data === 1
synthesize:
  role: conclusion
  fields:
  - key: severity
    label: 严重度
  - key: root_cause_type
    label: 根因类型
  - key: primary_category
    label: 主要类别
  - key: primary_pct
    label: 占比
    format: '{{value}}%'
  - key: suggestion
    label: 建议
  insights:
  - condition: severity === 'critical'
    template: IO 压力严重（{{root_cause_type}}）：{{suggestion}}
  - condition: severity === 'warning'
    template: IO 压力偏高（{{root_cause_type}}）：{{suggestion}}
display:
  level: summary
  layer: overview
  title: IO 压力根因
  columns:
  - name: total_io_ms
    label: 总 IO 等待
    type: duration
    format: duration_ms
    unit: ms
  - name: primary_category
    label: 主要类别
    type: string
  - name: primary_pct
    label: 占比
    type: percentage
  - name: severity
    label: 严重度
    type: string
  - name: root_cause_type
    label: 根因类型
    type: string
  - name: suggestion
    label: 建议
    type: string
save_as: root_cause
```
### IO 诊断

- ID: `io_diagnostic`
- Type: `diagnostic`

```yaml
id: io_diagnostic
type: diagnostic
rules:
- condition: (io_overview?.data?.[0]?.severity) === 'critical'
  severity: critical
  diagnosis: 'IO 压力严重: 总等待 ${io_overview.data[0].total_io_wait_ms}ms, 影响 ${io_overview.data[0].affected_threads} 个线程'
  suggestions:
  - 检查是否存在大文件读写或频繁的小文件操作
  - 考虑使用异步 IO 或 IO 调度优化
  - 检查存储设备健康状况
- condition: (io_overview?.data?.[0]?.severity) === 'warning'
  severity: warning
  diagnosis: 'IO 压力偏高: 总等待 ${io_overview.data[0].total_io_wait_ms}ms'
  suggestions:
  - 分析阻塞函数，定位 IO 热点
  - 考虑批量化 IO 操作
- condition: (root_cause?.data?.[0]?.root_cause_type) === 'IO_FS_BOUND'
  severity: warning
  diagnosis: 文件系统操作是主要 IO 瓶颈 (${root_cause.data[0].primary_pct}%)
  suggestions:
  - 优化文件读写模式，减少小文件操作
  - 使用 mmap 或缓存减少文件系统调用
- condition: (root_cause?.data?.[0]?.root_cause_type) === 'IO_SYNC_BOUND'
  severity: warning
  diagnosis: 同步操作频繁导致 IO 等待 (${root_cause.data[0].primary_pct}%)
  suggestions:
  - 减少 fsync 调用频率
  - 使用 write-back 缓存策略
- condition: (io_overview?.data?.[0]?.severity) === 'normal' || (io_overview?.data?.[0]?.severity) === 'info'
  severity: info
  diagnosis: IO 压力在正常范围内 (${io_overview.data[0].total_io_wait_ms}ms)
```
