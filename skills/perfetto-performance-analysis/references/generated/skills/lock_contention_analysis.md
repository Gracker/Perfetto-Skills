GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/lock_contention_analysis.skill.yaml
Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# 锁竞争分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: lock_contention_analysis
version: '3.0'
type: composite
category: performance
tier: S
```

## Metadata

```yaml
display_name: 锁竞争分析
description: 分析应用中的线程锁竞争情况，识别热点锁、锁链和持锁线程阻塞原因
icon: lock
tags:
- lock
- contention
- performance
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 锁
  - 锁竞争
  - 死锁
  - 等待锁
  - 同步
  - 锁链
  - monitor
  - 持锁
  - 抢锁
  en:
  - lock
  - contention
  - deadlock
  - monitor
  - synchronized
  - mutex
  - futex
  - lock chain
patterns:
- .*锁.*竞争.*
- .*lock.*contention.*
- .*死锁.*
- .*deadlock.*
- .*synchronized.*
- .*monitor.*
```

## Prerequisites

```yaml
required_tables:
- thread_state
modules:
- android.monitor_contention
- slices.with_context
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
  description: 目标进程名，留空分析所有锁竞争
- name: min_duration_ms
  type: number
  required: false
  default: 10
  description: 最小锁等待时间阈值（毫秒）
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

### 锁竞争数据检查

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/data_check.sql`](../sql/lock_contention_analysis/data_check.sql)

```yaml
id: data_check
type: atomic
optional: true
display: false
save_as: data_check
```
### 持锁线程归因事件

- ID: `owner_contention_events`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/owner_contention_events.sql`](../sql/lock_contention_analysis/owner_contention_events.sql)

```yaml
id: owner_contention_events
type: atomic
optional: true
display:
  level: key
  layer: list
  title: 持锁线程归因（Monitor + ART Lock contention）
  columns:
  - name: source
    label: 来源
    type: string
  - name: process_name
    label: 进程名
    type: string
  - name: lock_name
    label: 锁/方法
    type: string
  - name: lock_type
    label: 锁类型
    type: string
  - name: blocked_thread_name
    label: 等待线程
    type: string
  - name: blocking_thread_name
    label: 持锁线程
    type: string
  - name: owner_tid
    label: Owner TID
    type: number
  - name: owner_thread_state
    label: 持锁线程状态
    type: string
  - name: owner_blocked_function
    label: 持锁线程阻塞函数
    type: string
  - name: wait_ms
    label: 等待时长
    type: duration
    format: duration_ms
    unit: ms
  - name: owner_state_ms
    label: 状态重叠时长
    type: duration
    format: duration_ms
    unit: ms
save_as: owner_contention_events
```
### 锁竞争概览

- ID: `contention_overview`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/contention_overview.sql`](../sql/lock_contention_analysis/contention_overview.sql)

```yaml
id: contention_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: process_name
    label: 进程名
  - key: contention_count
    label: 竞争次数
  - key: total_blocked_time_ms
    label: 总阻塞时间
    format: '{{value}} ms'
  - key: main_thread_contentions
    label: 主线程竞争
  insights:
  - condition: total_blocked_time_ms > 1000
    template: 总锁阻塞时间 {{total_blocked_time_ms}}ms，严重影响性能
  - condition: main_thread_contentions > 20
    template: 主线程被阻塞 {{main_thread_contentions}} 次，影响 UI 流畅度
display:
  level: key
  layer: overview
  title: 锁竞争概览
  columns:
  - name: process_name
    label: 进程名
    type: string
  - name: contention_count
    label: 竞争次数
    type: number
    format: compact
  - name: total_blocked_time_ms
    label: 总阻塞时间
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_blocked_time_ms
    label: 平均阻塞时间
    type: duration
    format: duration_ms
    unit: ms
  - name: max_blocked_time_ms
    label: 最大阻塞时间
    type: duration
    format: duration_ms
    unit: ms
  - name: main_thread_contentions
    label: 主线程竞争
    type: number
    format: compact
  - name: avg_waiters
    label: 平均等待者数
    type: number
save_as: contention_overview
condition: data_check.data[0]?.status === 'available'
```
### 主线程锁竞争

- ID: `main_thread_contentions`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/main_thread_contentions.sql`](../sql/lock_contention_analysis/main_thread_contentions.sql)

```yaml
id: main_thread_contentions
type: atomic
synthesize:
  role: list
  groupBy:
  - field: blocking_thread_name
    title: 按阻塞线程分布
  fields:
  - key: short_blocking_method
    label: 持锁方法
  - key: total_blocked_ms
    label: 总阻塞时间
    format: '{{value}} ms'
  - key: blocking_thread_name
    label: 阻塞线程
  insights:
  - condition: blocker_is_main === 0 && total_blocked_ms > 100
    template: 主线程被后台线程 {{blocking_thread_name}} 持锁阻塞 {{total_blocked_ms}}ms
  - condition: avg_waiters > 5
    template: 多线程争抢同一把锁（平均 {{avg_waiters}} 个等待者）
display:
  level: key
  layer: list
  title: 主线程锁竞争详情
  columns:
  - name: process_name
    label: 进程名
    type: string
  - name: short_blocking_method
    label: 持锁方法
    type: string
  - name: blocking_thread_name
    label: 阻塞线程
    type: string
  - name: blocker_is_main
    label: 阻塞者是主线程
    type: number
  - name: contention_count
    label: 竞争次数
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
  - name: max_blocked_ms
    label: 最大阻塞时间
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_waiters
    label: 平均等待者
    type: number
save_as: main_thread_contentions
condition: data_check.data[0]?.status === 'available'
```
### 热点锁分析

- ID: `hot_locks`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/hot_locks.sql`](../sql/lock_contention_analysis/hot_locks.sql)

```yaml
id: hot_locks
type: atomic
display:
  level: key
  layer: list
  title: 热点锁 Top20
  columns:
  - name: short_blocking_method
    label: 持锁方法
    type: string
  - name: blocking_src
    label: 持锁源码位置
    type: string
  - name: contention_count
    label: 竞争次数
    type: number
    format: compact
  - name: unique_waiters
    label: 不同等待线程数
    type: number
  - name: total_contention_ms
    label: 总竞争时间
    type: duration
    format: duration_ms
    unit: ms
  - name: max_waiters
    label: 最大等待者
    type: number
save_as: hot_locks
condition: data_check.data[0]?.status === 'available'
```
### 锁链分析

- ID: `lock_chain_analysis`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/lock_chain_analysis.sql`](../sql/lock_contention_analysis/lock_chain_analysis.sql)

```yaml
id: lock_chain_analysis
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 锁链分析（锁传递检测）
  columns:
  - name: blocked_at
    label: 被阻塞方法
    type: string
  - name: waiting_for
    label: 等待的方法
    type: string
  - name: blocking_thread_name
    label: 阻塞线程
    type: string
  - name: has_parent
    label: 有上游
    type: number
  - name: has_child
    label: 有下游
    type: number
  - name: blocked_ms
    label: 阻塞时间
    type: duration
    format: duration_ms
    unit: ms
  - name: waiter_count
    label: 等待者数
    type: number
save_as: lock_chain_analysis
condition: data_check.data[0]?.status === 'available'
```
### 持锁线程状态

- ID: `blocking_thread_state`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/blocking_thread_state.sql`](../sql/lock_contention_analysis/blocking_thread_state.sql)

```yaml
id: blocking_thread_state
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 持锁线程状态分布
  columns:
  - name: thread_state
    label: 线程状态
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总时间
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均时间
    type: duration
    format: duration_ms
    unit: ms
save_as: blocking_thread_state
condition: data_check.data[0]?.status === 'available'
```
### 持锁时阻塞函数

- ID: `blocking_functions`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/blocking_functions.sql`](../sql/lock_contention_analysis/blocking_functions.sql)

```yaml
id: blocking_functions
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 持锁线程内核阻塞函数 Top20
  columns:
  - name: blocked_function
    label: 内核阻塞函数
    type: string
  - name: total_dur_ms
    label: 总时间
    type: duration
    format: duration_ms
    unit: ms
  - name: count
    label: 次数
    type: number
    format: compact
  - name: avg_dur_ms
    label: 平均时间
    type: duration
    format: duration_ms
    unit: ms
save_as: blocking_functions
condition: data_check.data[0]?.status === 'available'
```
### 锁竞争与 Binder 关联

- ID: `contention_binder_correlation`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/contention_binder_correlation.sql`](../sql/lock_contention_analysis/contention_binder_correlation.sql)

```yaml
id: contention_binder_correlation
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 锁竞争期间的 Binder 关联
  columns:
  - name: process_name
    label: 进程名
    type: string
  - name: short_blocking_method
    label: 持锁方法
    type: string
  - name: in_binder_txn
    label: 在 Binder 事务中
    type: number
  - name: contention_count
    label: 竞争次数
    type: number
    format: compact
  - name: avg_contention_ms
    label: 平均竞争时间
    type: duration
    format: duration_ms
    unit: ms
save_as: contention_binder_correlation
condition: data_check.data[0]?.status === 'available'
```
### 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/root_cause_classification.sql`](../sql/lock_contention_analysis/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
synthesize:
  role: conclusion
  fields:
  - key: category
    label: 问题类别
  - key: severity
    label: 严重程度
  - key: description
    label: 描述
  insights:
  - template: 锁竞争诊断：{{category}} - {{description}}
display:
  level: summary
  layer: overview
  title: 锁竞争分析结论
  columns:
  - name: category
    label: 问题类别
    type: enum
  - name: severity
    label: 严重程度
    type: enum
  - name: description
    label: 描述
    type: string
  - name: evidence
    label: 证据
    type: string
save_as: root_cause
condition: data_check.data[0]?.status === 'available'
```
### 数据不可用提示

- ID: `fallback_no_data`
- Type: `atomic`
- SQL: [`../sql/lock_contention_analysis/fallback_no_data.sql`](../sql/lock_contention_analysis/fallback_no_data.sql)

```yaml
id: fallback_no_data
type: atomic
condition: data_check.data[0]?.status === 'unavailable'
display:
  level: summary
  layer: overview
  title: 锁竞争分析 - 无数据
  columns:
  - name: status
    label: 状态
    type: string
  - name: suggestion
    label: 建议
    type: string
save_as: fallback_info
```
## Output and evidence contract

```yaml
format: structured
```
