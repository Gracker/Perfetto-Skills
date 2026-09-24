GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
Source SHA-256: 88ec9683e76751ade4cdc4a899a482dfba921d757006beab05b108b52ba9d299
Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad
# ANR 主线程阻塞链分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: anr_main_thread_blocking
version: '1.1'
type: composite
category: anr
tier: S
```

## Metadata

```yaml
display_name: ANR 主线程阻塞链分析
description: 分析主线程等待；无 ANR 时间戳或目标进程时发现应用主线程长等待候选，再结合输入时间线判断是否无响应
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
  required: false
  default: ''
  description: 目标进程名；省略时仅通过 wakeup_chain 发现各应用主线程最长等待候选，不判定 ANR
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
- name: min_wait_ms
  type: number
  required: false
  description: 无目标发现模式的最短单段等待毫秒数，默认 3000
- name: top_n
  type: number
  required: false
  description: 无目标发现模式的候选条数，默认 20，上限 100
- name: offset
  type: number
  required: false
  description: 无目标发现模式的分页偏移，默认 0
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
    template: 主线程 {{pct}}% 时间处于 Sleep 状态；正常空闲也可如此，需输入处理或调用链证据判断是否异常等待
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
  title: 主线程等待候选与唤醒证据（长睡眠不等于无响应）
  columns:
  - name: process_name
    label: 进程名
    type: string
  - name: candidate_status
    label: 候选证据边界
    type: string
  - name: upid
    label: upid
    type: number
  - name: utid
    label: utid
    type: number
  - name: thread_state_id
    label: 等待事件ID
    type: number
  - name: raw_start_ts
    label: 原始等待开始
    type: timestamp
    unit: ns
  - name: raw_end_ts
    label: 原始等待结束
    type: timestamp
    unit: ns
  - name: start_ts
    label: 窗口内等待开始
    type: timestamp
    unit: ns
  - name: end_ts
    label: 窗口内等待结束
    type: timestamp
    unit: ns
  - name: is_unfinished
    label: 未结束等待
    type: number
  - name: left_censored
    label: 左边界裁剪
    type: number
  - name: right_censored
    label: 右边界裁剪
    type: number
  - name: wakeup_state_id
    label: 后继状态ID
    type: number
  - name: waker_utid
    label: 唤醒线程身份
    type: number
  - name: waker_upid
    label: 唤醒进程身份
    type: number
  - name: observed_waker_utid
    label: 原始唤醒线程字段
    type: number
  - name: irq_context
    label: IRQ上下文
    type: number
  - name: wakeup_status
    label: 唤醒证据状态
    type: string
  - name: relation_status
    label: 关系证据边界
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
  - name: wait_span_count
    label: 等待区间数
    type: number
  - name: blocked_state
    label: 等待状态
    type: string
  - name: ts
    label: 后继 Runnable 事件时间
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
    label: 窗口内等待时长(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: wakeup_count
    label: 有唤醒元数据的事件数
    type: number
    format: compact
sql_fragments:
- fragments/system_thread_state_spans.sql
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
