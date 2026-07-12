GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_thread_blocking_graph.skill.yaml
Source SHA-256: efc99dd7288f62ffa136feb19c852594d545620e9a17523b1070b71f14041d67
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d
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
description: 分析启动期间线程间的 block/wakeup 关系，定位阻塞根因
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
title: 线程阻塞关系图
columns:
- name: blocked_thread
  label: 被阻塞线程
  type: string
- name: blocked_role
  label: 被阻塞角色
  type: string
- name: blocked_state
  label: 阻塞状态
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
  label: 阻塞次数
  type: number
- name: total_block_ms
  label: 总阻塞时间
  type: duration
  format: duration_ms
  unit: ms
- name: max_block_ms
  label: 最大阻塞时间
  type: duration
  format: duration_ms
  unit: ms
- name: avg_block_ms
  label: 平均阻塞时间
  type: duration
  format: duration_ms
  unit: ms
```
