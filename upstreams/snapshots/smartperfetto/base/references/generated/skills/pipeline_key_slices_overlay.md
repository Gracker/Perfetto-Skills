GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/pipeline_key_slices_overlay.skill.yaml
Source SHA-256: 34b2abe52c508a34d1fb3f9794fbac79210dc3ee9fb9e3d4305b68a4c3699b97
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# 管线关键 Slice 时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_key_slices_overlay
version: '1.0'
type: atomic
category: pipeline
tier: B
```

## Metadata

```yaml
display_name: 管线关键 Slice 时间线
description: 查询管线关键 Slice 的实际 ts/dur 数据用于时间线 overlay
icon: timeline
tags:
- pipeline
- teaching
- overlay
- timeline
- atomic
```

## Inputs

```yaml
- name: slice_names
  type: json_array
  required: true
  description: 'Portable binding: pass a JSON array through --param; do not pass a preformatted SQL list.'
  source_type: string
  source_description: SQL IN 列表格式的 Slice 名称，如 'Choreographer#doFrame','DrawFrame','syncFrameState'
- name: package
  type: string
  required: false
  description: 可选包名/进程名前缀；为空时不过滤 App 进程，始终保留 SurfaceFlinger/system_server
- name: start_ts
  type: number
  required: false
  description: 可选时间窗起点(ns)，用于把 overlay 限定在 selection 或 visible window
- name: end_ts
  type: number
  required: false
  description: 可选时间窗终点(ns)，用于把 overlay 限定在 selection 或 visible window
```

## Ordered execution

### 管线关键 Slice 查询

- ID: `pipeline_key_slices_overlay`
- Type: `atomic`
- SQL: [`../sql/pipeline_key_slices_overlay/pipeline_key_slices_overlay.sql`](../sql/pipeline_key_slices_overlay/pipeline_key_slices_overlay.sql)

```yaml
id: pipeline_key_slices_overlay
type: atomic
display:
  level: hidden
  layer: deep
  title: 管线关键 Slice
  columns:
  - name: ts
    type: timestamp
    unit: ns
  - name: dur
    type: duration
    unit: ns
  - name: slice_name
    type: string
  - name: dur_ms
    type: number
  - name: thread_name
    type: string
  - name: process_name
    type: string
  - name: track_id
    type: number
  - name: utid
    type: number
  - name: pipeline_stage
    type: string
  - name: description
    type: string
```
