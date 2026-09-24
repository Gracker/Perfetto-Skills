GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/scene_response_markers.skill.yaml
Source SHA-256: ffba8ce063278ad7adf1117f3147088dbb88f6d85aff3296d7cba291e26b6d50
Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df
# 场景响应原始标记

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: scene_response_markers
version: '1.0'
type: composite
category: input_response
tier: B
```

## Metadata

```yaml
display_name: 场景响应原始标记
description: 读取 Scroll、FlingStart 原始 slice 及线程或进程 track 归属；持续时间仅表示标记执行区间，不解释 name 内 duration，也不证明完整滚动、惯性或呈现。
icon: timeline
tags:
- scene
- response
- scroll
- fling
- marker
- raw
- interval
```

## Prerequisites

```yaml
required_tables:
- slice
- track
- thread_track
- thread
- process_track
- process
- trace_bounds
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
- name: row_limit
  type: number
  required: false
  default: 4096
```

## Ordered execution

### 响应标记扫描范围

- ID: `response_sources`
- Type: `atomic`
- SQL: [`../sql/scene_response_markers/response_sources.sql`](../sql/scene_response_markers/response_sources.sql)

```yaml
id: response_sources
type: atomic
display:
  level: detail
  layer: overview
  title: 响应标记扫描范围
sql_fragments:
- fragments/scene_response_marker_facts.sql
save_as: response_sources
```
### 响应标记原始区间

- ID: `response_markers`
- Type: `atomic`
- SQL: [`../sql/scene_response_markers/response_markers.sql`](../sql/scene_response_markers/response_markers.sql)

```yaml
id: response_markers
type: atomic
display:
  level: detail
  layer: list
  title: 响应标记原始区间
  columns:
  - name: slice_id
    label: Slice ID
    type: number
  - name: ts
    label: 标记开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur
    label: 标记持续
    type: duration
    unit: ns
  - name: end_ts
    label: 标记结束
    type: timestamp
    unit: ns
  - name: raw_name
    label: 标记原文
    type: string
  - name: process_name
    label: 所属进程
    type: string
  - name: thread_name
    label: 所属线程
    type: string
  - name: identity_basis
    label: 归属来源
    type: string
  - name: source_status
    label: 观测状态
    type: string
sql_fragments:
- fragments/scene_response_marker_facts.sql
save_as: response_markers
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- response_sources
- response_markers
```
