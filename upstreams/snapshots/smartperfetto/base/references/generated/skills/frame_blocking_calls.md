GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/frame_blocking_calls.skill.yaml
Source SHA-256: ee76c4261a9a7084ff1f269894e9e029305381044bfc502210772faefaf06694
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# 帧阻塞调用分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: frame_blocking_calls
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: 帧阻塞调用分析
description: 识别每个掉帧帧期间的阻塞调用（GC、Binder、锁竞争、IO 等）
icon: block
tags:
- frame
- blocking
- jank
- root_cause
- diagnostics
pipeline_aware: true
pipeline_aware_note: '"阻塞调用"分析当前 pipeline-agnostic（main thread）。未来按 pipeline_id 切换：

  Flutter 看 1.ui 阻塞；Game 看 GameThread；RN 看 mqt_js。

  '
```

## Triggers

```yaml
keywords:
  zh:
  - 帧阻塞
  - 阻塞调用
  - Binder 阻塞
  - 文件 IO
  - futex
  - 锁竞争
  en:
  - frame blocking
  - blocking calls
  - binder blocking
  - file io
  - futex
patterns:
- .*帧.*(阻塞|Binder|IO|futex|锁).*
- .*frame.*(blocking|binder|io|futex).*
```

## Prerequisites

```yaml
modules:
- android.frames.timeline
- android.critical_blocking_calls
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
  description: 分析起始时间戳(ns，可选)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns，可选)
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

## Query

Run [`../sql/frame_blocking_calls/query.sql`](../sql/frame_blocking_calls/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
display:
  level: key
  layer: list
  title: 掉帧帧阻塞调用明细
  columns:
  - name: frame_id
    label: 帧 ID
    type: string
  - name: frame_ts
    label: 帧时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: frame_dur_ms
    label: 帧耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: jank_type
    label: Jank 类型
    type: string
  - name: thread_role
    label: 线程角色
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: blocking_call
    label: 阻塞调用
    type: string
  - name: overlap_ms
    label: 重叠时间(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: call_dur_ms
    label: 调用耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: call_count
    label: 调用次数
    type: number
    format: compact
```

## Display metadata

```yaml
level: key
layer: list
title: 掉帧帧阻塞调用明细
columns:
- name: frame_id
  label: 帧 ID
  type: string
- name: frame_ts
  label: 帧时间
  type: timestamp
  unit: ns
  clickAction: navigate_timeline
- name: frame_dur_ms
  label: 帧耗时(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: jank_type
  label: Jank 类型
  type: string
- name: thread_role
  label: 线程角色
  type: string
- name: thread_name
  label: 线程
  type: string
- name: blocking_call
  label: 阻塞调用
  type: string
- name: overlap_ms
  label: 重叠时间(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: call_dur_ms
  label: 调用耗时(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: call_count
  label: 调用次数
  type: number
  format: compact
```
