GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/lock_contention_in_range.skill.yaml
Source SHA-256: 5ab49bd436eb79f8d1bdc21b06e2b662481cb3335728c1776c55c8b0fab0f99b
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 锁竞争分析 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: lock_contention_in_range
version: '1.0'
type: atomic
category: performance
tier: A
```

## Metadata

```yaml
display_name: 锁竞争分析 (区间)
description: 分析指定时间范围内的锁竞争情况
icon: lock
tags:
- lock
- contention
- performance
- atomic
```

## Prerequisites

```yaml
required_tables:
- thread_state
- android_monitor_contention
modules:
- android.monitor_contention
- slices.with_context
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
- name: end_ts
  type: timestamp
  required: true
- name: package
  type: string
  required: false
```

## Ordered execution

### Java Monitor 锁竞争

- ID: `monitor_contentions`
- Type: `atomic`
- SQL: [`../sql/lock_contention_in_range/monitor_contentions.sql`](../sql/lock_contention_in_range/monitor_contentions.sql)

```yaml
id: monitor_contentions
type: atomic
display:
  level: detail
  title: Java Monitor 锁竞争
  columns:
  - name: blocking_method
    label: 持锁方法
    type: string
  - name: blocking_thread_name
    label: 持锁线程
    type: string
  - name: blocked_method
    label: 阻塞方法
    type: string
  - name: blocked_thread_name
    label: 阻塞线程
    type: string
  - name: main_blocked
    label: 主线程阻塞
    type: boolean
  - name: wait_ms
    label: 等待时长
    type: duration
    format: duration_ms
    unit: ms
  - name: waiter_count
    label: 等待数
    type: number
  - name: lock_type
    label: 锁类型
    type: string
save_as: monitor_contentions
optional: true
```
### 持锁线程归因

- ID: `owner_contentions`
- Type: `atomic`
- SQL: [`../sql/lock_contention_in_range/owner_contentions.sql`](../sql/lock_contention_in_range/owner_contentions.sql)

```yaml
id: owner_contentions
type: atomic
optional: true
display:
  level: detail
  title: 持锁线程归因（Monitor + ART Lock contention）
  columns:
  - name: source
    label: 来源
    type: string
  - name: process_name
    label: 进程
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
save_as: owner_contentions
```
### Futex 等待

- ID: `futex_waits`
- Type: `atomic`
- SQL: [`../sql/lock_contention_in_range/futex_waits.sql`](../sql/lock_contention_in_range/futex_waits.sql)

```yaml
id: futex_waits
type: atomic
display:
  level: detail
  title: Futex/Mutex 等待
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: wait_ms
    label: 等待时长
    type: duration
    format: duration_ms
    unit: ms
  - name: process_name
    label: 进程
    type: string
  - name: lock_type
    label: 锁类型
    type: string
  - name: is_main_thread
    label: 主线程
    type: boolean
save_as: futex_waits
optional: true
```
### 锁竞争汇总

- ID: `lock_summary`
- Type: `atomic`
- SQL: [`../sql/lock_contention_in_range/lock_summary.sql`](../sql/lock_contention_in_range/lock_summary.sql)

```yaml
id: lock_summary
type: atomic
optional: true
display:
  level: summary
  title: 锁竞争汇总
  columns:
  - name: java_monitor_count
    label: Java锁次数
    type: number
    format: compact
  - name: futex_mutex_count
    label: Futex次数
    type: number
    format: compact
  - name: total_contentions
    label: 总竞争次数
    type: number
    format: compact
  - name: java_monitor_wait_ms
    label: Java锁等待
    type: duration
    format: duration_ms
    unit: ms
  - name: futex_mutex_wait_ms
    label: Futex等待
    type: duration
    format: duration_ms
    unit: ms
  - name: total_wait_ms
    label: 总等待
    type: duration
    format: duration_ms
    unit: ms
  - name: max_monitor_wait_ms
    label: 最大Java锁等待
    type: duration
    format: duration_ms
    unit: ms
  - name: main_thread_blocked_count
    label: 主线程阻塞
    type: number
    format: compact
save_as: summary
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: monitor_contentions
  description: Java Monitor 锁竞争事件
- name: owner_contentions
  description: 持锁线程归因事件（Monitor + ART Lock contention）
- name: futex_waits
  description: Futex/pthread_mutex 等待事件
- name: summary
  description: 锁竞争汇总统计
```
