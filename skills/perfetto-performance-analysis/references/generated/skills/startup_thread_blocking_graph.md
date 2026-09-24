GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_thread_blocking_graph.skill.yaml
Source SHA-256: 69238dda35542463041b9a6abaac5497e3ce646dd30ab5172692caa825eb5d2f
Source commit: e7ff73a937cc66d89fdc69d59728025734759acd
# 启动线程阻塞关系图

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_thread_blocking_graph
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 启动线程阻塞关系图
description: 观测启动期间的等待区间和后继唤醒事件；唤醒者身份不证明阻塞原因
icon: account_tree
tags:
- startup
- blocking
- wakeup
- thread_graph
- atomic
```

## Prerequisites

```yaml
modules: null
```

## Inputs

```yaml
- name: package
  type: string
  required: true
- name: start_ts
  type: timestamp
  required: true
- name: end_ts
  type: timestamp
  required: true
- name: min_block_ms
  type: number
  required: false
- name: top_k
  type: number
  required: false
```

## Query

Run [`../sql/startup_thread_blocking_graph/query.sql`](../sql/startup_thread_blocking_graph/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 等待区间与唤醒事件
columns:
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
- name: evidence_scope
  label: 证据范围
  type: string
- name: waker_slice_id
  label: 唤醒时操作ID
  type: number
- name: upid
  label: upid
  type: number
  hidden: true
- name: utid
  label: utid
  type: number
  hidden: true
- name: thread_state_id
  label: thread_state_id
  type: number
  hidden: true
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
- name: wakeup_ts
  label: 后继事件时间
  type: timestamp
  unit: ns
- name: wakeup_status
  label: 唤醒证据状态
  type: string
- name: wakeup_count
  label: 有唤醒元数据的事件数
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
  label: IRQ 上下文
  type: number
- name: relation_status
  label: 关系证据边界
  type: string
- name: waker_slice_status
  label: 唤醒时操作证据
  type: string
- name: blocked_thread
  label: 等待线程
  type: string
- name: blocked_role
  label: 等待线程角色
  type: string
- name: blocked_state
  label: 等待状态
  type: string
- name: blocked_function
  label: 阻塞函数
  type: string
  format: code
- name: waker_thread
  label: 唤醒者线程
  type: string
- name: waker_process
  label: 唤醒者进程
  type: string
- name: waker_current_slice
  label: 唤醒者当时操作
  type: string
- name: block_count
  label: 等待区间数
  type: number
- name: total_block_ms
  label: 窗口内等待时长
  type: duration
  format: duration_ms
  unit: ms
- name: max_block_ms
  label: 单区间等待时长
  type: duration
  format: duration_ms
  unit: ms
- name: avg_block_ms
  label: 单区间等待时长
  type: duration
  format: duration_ms
  unit: ms
```
