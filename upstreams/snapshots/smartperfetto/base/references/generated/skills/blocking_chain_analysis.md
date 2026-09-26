GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/blocking_chain_analysis.skill.yaml
Source SHA-256: ec3db5b12031c8cedf7480f0e7496dd03c5a0e7ecad513cc72cd26cf8e68c0a2
Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799
# 阻塞链分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: blocking_chain_analysis
version: '1.3'
type: composite
category: diagnostics
tier: A
```

## Metadata

```yaml
display_name: 阻塞链分析
description: 分析指定时间范围内主线程的阻塞链：谁阻塞了主线程？唤醒者是谁？唤醒者在做什么？
icon: link
tags:
- blocking
- waker
- chain
- root_cause
- diagnostics
```

## Prerequisites

```yaml
required_tables:
- thread_state
- thread
- process
```

## Inputs

```yaml
- name: process_name
  type: string
  required: true
  description: 目标进程名
- name: start_ts
  type: timestamp
  required: true
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 分析结束时间戳(ns)
- name: min_wait_ms
  type: number
  required: false
  description: 多跳唤醒链追踪的最小等待时长(ms)
- name: max_hops
  type: number
  required: false
  description: 唤醒链最大跳数
- name: top_waits
  type: number
  required: false
  description: 追踪的等待区间数（按时长降序）
```

## Identity requirements

```yaml
policy: required
scope: process
aliases:
- process_name
- package
rewriteTo: recommended_process_name_param
```

## Ordered execution

### 主线程状态分布

- ID: `thread_state_distribution`
- Type: `atomic`
- SQL: [`../sql/blocking_chain_analysis/thread_state_distribution.sql`](../sql/blocking_chain_analysis/thread_state_distribution.sql)

```yaml
id: thread_state_distribution
type: atomic
display:
  level: key
  layer: overview
  show: false
  title: 主线程状态分布（指定时间范围）
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
  - name: blocked_function
    label: 主要阻塞函数
    type: string
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
save_as: thread_state_distribution
```
### 唤醒链分析

- ID: `waker_chain`
- Type: `atomic`
- SQL: [`../sql/blocking_chain_analysis/waker_chain.sql`](../sql/blocking_chain_analysis/waker_chain.sql)

```yaml
id: waker_chain
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
  - name: waker_role
    label: 唤醒者角色
    type: string
  - name: wake_source
    label: 唤醒来源
    type: string
  - name: wait_class
    label: 等待类别（候选）
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: total_sleep_dur_ms
    label: 总 Sleep 时长(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: max_sleep_dur_ms
    label: 最大 Sleep 时长(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: wakeup_count
    label: 唤醒次数
    type: number
    format: compact
sql_fragments:
- fragments/thread_role.sql
- fragments/sleep_wake_source.sql
- fragments/sleep_wake_source_labels.sql
save_as: waker_chain
optional: true
```
### 多跳唤醒链追踪

- ID: `wakeup_chain_trace`
- Type: `atomic`
- SQL: [`../sql/blocking_chain_analysis/wakeup_chain_trace.sql`](../sql/blocking_chain_analysis/wakeup_chain_trace.sql)

```yaml
id: wakeup_chain_trace
type: atomic
display:
  level: detail
  layer: list
  title: 主线程长等待的多跳唤醒链（谁最终唤醒了主线程）
  columns:
  - name: wait_start_ts
    label: 等待开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: wait_ms
    label: 总等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: hop
    label: 跳数
    type: number
    format: compact
  - name: waker_thread_name
    label: 该跳线程
    type: string
  - name: waker_process_name
    label: 所属进程
    type: string
  - name: waker_runnable_ts
    label: 该跳被唤醒时刻
    type: timestamp
    unit: ns
  - name: waker_wait_before_ms
    label: 该跳此前等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: run_ms_in_wait
    label: 等待窗口内运行(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: chain_status
    label: 链状态
    type: string
save_as: wakeup_chain_trace
optional: true
```
### 阻塞函数汇总

- ID: `blocked_function_summary`
- Type: `atomic`
- SQL: [`../sql/blocking_chain_analysis/blocked_function_summary.sql`](../sql/blocking_chain_analysis/blocked_function_summary.sql)

```yaml
id: blocked_function_summary
type: atomic
display:
  level: key
  layer: list
  title: 主线程阻塞函数分布 Top 10
  columns:
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: total_dur_ms
    label: 总阻塞时间(ms)
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
save_as: blocked_function_summary
optional: true
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- thread_state_distribution
- waker_chain
- wakeup_chain_trace
- blocked_function_summary
```
