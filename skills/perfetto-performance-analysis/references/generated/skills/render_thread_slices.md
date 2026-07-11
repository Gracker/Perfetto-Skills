GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/render_thread_slices.skill.yaml
Source SHA-256: cc1e3d5e7156fb21c9208867164cb287e368f620dae68b1f3e289076316b4435
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 渲染线程 Slice 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: render_thread_slices
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: 渲染线程 Slice 分析
description: 分析渲染线程的时间片分布
icon: brush
tags:
- rendering
- thread
- slice
- atomic
pipeline_aware: true
pipeline_aware_note: '"RenderThread"在不同 pipeline 是不同线程：

  - 标准 HWUI: RenderThread

  - Flutter: 1.raster

  - Game: RHIThread (UE) / UnityGfx (Unity)

  - WebView Functor: 宿主 RenderThread（含 Functor replay）

  未来按 pipeline_id 切换 thread filter SQL。

  '
```

## Triggers

```yaml
keywords:
  zh:
  - RenderThread
  - 渲染线程
  - 渲染 slice
  - GPU 指令
  - raster
  en:
  - renderthread
  - render thread
  - render slices
  - raster thread
patterns:
- .*(RenderThread|渲染线程|raster).*
- .*render.*(thread|slice).*
```

## Prerequisites

```yaml
required_tables:
- slice
- thread_track
- thread
- process
modules:
- slices.with_context
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 分析结束时间戳(ns)
- name: package
  type: string
  required: false
  description: 应用包名
```

## Ordered execution

### RenderThread 耗时操作

- ID: `render_slices`
- Type: `atomic`
- SQL: [`../sql/render_thread_slices/render_slices.sql`](../sql/render_thread_slices/render_slices.sql)

```yaml
id: render_slices
type: atomic
display:
  level: key
  title: RenderThread 耗时操作
  columns:
  - name: name
    label: 操作
    type: string
  - name: total_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: count
    label: 次数
    type: number
    format: compact
  - name: max_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
save_as: render_slices
```
## Output and evidence contract

```yaml
format: structured
```
