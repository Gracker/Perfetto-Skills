GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
Source SHA-256: 752e67cdf5dd546d65645a1b6da52ba9ab151e46610423c7390997c6e0d4d7a9
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d
# ANR 主线程阻塞链分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: anr_main_thread_blocking
version: '1.0'
type: composite
category: anr
tier: S
```

## Metadata

```yaml
display_name: ANR 主线程阻塞链分析
description: 深度分析 ANR 事件中主线程的阻塞原因：线程状态、阻塞函数、唤醒链、Binder、锁竞争
icon: bug_report
tags:
- anr
- blocking
- main_thread
- deadlock
- binder
- lock
- atomic
```

## Prerequisites

```yaml
required_tables:
- thread_state
- thread
- process
modules:
- android.binder
- android.monitor_contention
```

## Inputs

```yaml
- name: process_name
  type: string
  required: true
  description: 目标进程名
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: anr_ts
  type: timestamp
  required: false
  description: ANR 事件时间戳(ns)，用于自动计算分析窗口
```

## Ordered execution

### 主线程状态分布

- ID: `main_thread_state`
- Type: `atomic`
- SQL: [`../sql/anr_main_thread_blocking/main_thread_state.sql`](../sql/anr_main_thread_blocking/main_thread_state.sql)

```yaml
id: main_thread_state
type: atomic
display:
  level: key
  layer: overview
  title: ANR 窗口主线程状态分布
  columns:
  - name: state
    label: 线程状态
    type: string
  - name: state_display
    label: 状态说明
    type: string
  - name: total_dur_ms
    label: 总时间(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: count
    label: 次数
    type: number
    format: compact
  - name: pct
    label: 占比(%)
    type: percentage
    format: percentage
  - name: avg_dur_ms
    label: 平均时间(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: max_dur_ms
    label: 最大时间(ms)
    type: duration
    format: duration_ms
    unit: ms
synthesize:
  role: overview
  fields:
  - key: state_display
    label: 状态
  - key: pct
    label: 占比
    format: '{{value}}%'
  - key: total_dur_ms
    label: 总时间
    format: '{{value}} ms'
  insights:
  - condition: state === 'S' && pct > 50
    template: 主线程 {{pct}}% 时间处于 Sleep 状态，可能在等待锁或 Binder
  - condition: state === 'D' && pct > 20
    template: 主线程 {{pct}}% 时间处于不可中断睡眠 (D)，需结合 io_wait/blocked_function 判断是否为 IO
  - condition: state === 'R' && pct > 80
    template: 主线程 {{pct}}% 时间处于 Runnable/Running，CPU 争抢或繁忙
save_as: main_thread_state
```
### 阻塞函数分析

- ID: `blocked_functions`
- Type: `atomic`
- SQL: [`../sql/anr_main_thread_blocking/blocked_functions.sql`](../sql/anr_main_thread_blocking/blocked_functions.sql)

```yaml
id: blocked_functions
type: atomic
display:
  level: key
  layer: list
  title: 主线程 Sleep 阻塞函数 Top
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: dur_ms
    label: 阻塞时间(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总阻塞时间(ms)
    type: duration
    format: duration_ms
    unit: ms
save_as: blocked_functions
optional: true
```
### 唤醒链分析

- ID: `wakeup_chain`
- Type: `atomic`
- SQL: [`../sql/anr_main_thread_blocking/wakeup_chain.sql`](../sql/anr_main_thread_blocking/wakeup_chain.sql)

```yaml
id: wakeup_chain
type: atomic
display:
  level: key
  layer: list
  title: 主线程唤醒链（谁唤醒了主线程）
  columns:
  - name: ts
    label: 唤醒时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: waker_thread_name
    label: 唤醒者线程
    type: string
  - name: waker_process_name
    label: 唤醒者进程
    type: string
  - name: sleep_dur_ms
    label: Sleep 时长(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: wakeup_count
    label: 唤醒次数
    type: number
    format: compact
save_as: wakeup_chain
optional: true
```
### Binder 阻塞分析

- ID: `binder_blocking`
- Type: `atomic`
- SQL: [`../sql/anr_main_thread_blocking/binder_blocking.sql`](../sql/anr_main_thread_blocking/binder_blocking.sql)

```yaml
id: binder_blocking
type: atomic
display:
  level: key
  layer: list
  title: 主线程 Binder 同步调用
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: slice_name
    label: Binder 调用
    type: string
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: server_process
    label: 服务端进程
    type: string
  - name: server_thread
    label: 服务端线程
    type: string
save_as: binder_blocking
optional: true
```
### 锁竞争分析

- ID: `lock_contention`
- Type: `atomic`
- SQL: [`../sql/anr_main_thread_blocking/lock_contention.sql`](../sql/anr_main_thread_blocking/lock_contention.sql)

```yaml
id: lock_contention
type: atomic
display:
  level: detail
  layer: list
  title: 主线程锁等待 (Monitor/Futex)
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: lock_type
    label: 锁类型
    type: string
  - name: slice_name
    label: Slice 名称
    type: string
  - name: dur_ms
    label: 等待时间(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: thread_name
    label: 线程
    type: string
save_as: lock_contention
optional: true
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- main_thread_state
- blocked_functions
- wakeup_chain
```
