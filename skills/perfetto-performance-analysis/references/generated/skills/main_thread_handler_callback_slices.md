GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/main_thread_handler_callback_slices.skill.yaml
Source SHA-256: a143b158022ef674ec5b0171ce6e62301fa5e0cc95e2f7a202c82508e7383765
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# 主线程 Handler 回调切片

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: main_thread_handler_callback_slices
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 主线程 Handler 回调切片
description: 统计 trace 中实际观测到的主线程 Handler 回调执行切片；不代表消息排队等待或根因
icon: timer
tags:
- main_thread
- handler
- looper
- message_queue
- callback
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - Handler
  - Looper
  - 消息队列
  - 主线程回调
  en:
  - Handler callback
  - Looper
  - message queue
  - main thread callback
patterns:
- (?i)(handler|looper).*(callback|message|slice)
```

## Prerequisites

```yaml
required_tables:
- slice
- thread_track
- thread
- process
modules:
- android.slices
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  default: ''
  description: 目标进程/包名前缀；为空时覆盖所有进程
- name: start_ts
  type: timestamp
  required: false
  default: 0
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  default: 0
  description: 分析结束时间戳(ns)；0 表示 trace 结束
- name: min_dur_ns
  type: integer
  required: false
  default: 100000
  description: 最小回调执行时长(ns)，默认 0.1ms
- name: top_k
  type: integer
  required: false
  default: 20
  description: 返回的回调类型数量
```

## Ordered execution

### 主线程 Handler 回调执行

- ID: `callback_slices`
- Type: `atomic`
- SQL: [`../sql/main_thread_handler_callback_slices/callback_slices.sql`](../sql/main_thread_handler_callback_slices/callback_slices.sql)

```yaml
id: callback_slices
type: atomic
display:
  level: detail
  layer: list
  title: 主线程 Handler 回调执行
  columns:
  - name: raw_slice_name
    label: 原始切片名
    type: string
  - name: standardized_slice_name
    label: 标准化切片名
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 主线程
    type: string
  - name: callback_count
    label: 次数
    type: number
    format: compact
  - name: total_ms
    label: 总执行时长
    type: duration
    format: duration_ms
  - name: avg_ms
    label: 平均执行时长
    type: duration
    format: duration_ms
  - name: max_ms
    label: 最长执行时长
    type: duration
    format: duration_ms
  - name: first_ts
    label: 首次时间
    type: timestamp
  - name: last_ts
    label: 末次时间
    type: timestamp
  - name: evidence_scope
    label: 证据边界
    type: string
```
