GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_thread_blocking_graph.skill.yaml
Source SHA-256: eaa6929c7ddf3ad7bf3920f4a29d76ecd82be66cbfc6b032b7306156bd54507f
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 启动线程阻塞关系图

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

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
modules:
- sched
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
