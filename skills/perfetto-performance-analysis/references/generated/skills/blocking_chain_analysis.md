GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/blocking_chain_analysis.skill.yaml
Source SHA-256: d2c7a63dade5310e92b508c129b78b4e3a420c57d613ac75107d93e89f7418cf
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 阻塞链分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: blocking_chain_analysis
version: '1.0'
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
save_as: waker_chain
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
- blocked_function_summary
```
