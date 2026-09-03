GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/textureview_producer_frame_timing.skill.yaml
Source SHA-256: a2c34451c741e02fc6d13ed92dc82fdb910606ab79c16c5996ce90becc55c588
Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f
# TextureView 生产端帧时序

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: textureview_producer_frame_timing
version: '1.1'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: TextureView 生产端帧时序
description: 区分 TextureView / SurfaceTexture 生产、出队与消费通知，并检测同类事件流中的帧节奏缺口候选
icon: texture
tags:
- textureview
- surfacetexture
- producer
- frame_timing
- jank
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - TextureView
  - SurfaceTexture
  - updateTexImage
  - onFrameAvailable
  - 生产端掉帧
  - 纹理帧间隔
  en:
  - textureview
  - surfacetexture
  - updateTexImage
  - onFrameAvailable
  - producer frame timing
patterns:
- .*(TextureView|SurfaceTexture).*(卡顿|掉帧|帧间隔|生产端).*
- .*(textureview|surfacetexture).*(jank|frame timing|producer|gap).*
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
- android.frames.timeline
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标进程名（支持 GLOB）
- name: process_name
  type: string
  required: false
  description: 目标进程名别名；当 package 为空时使用
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: target_frame_ms
  type: number
  required: false
  description: 显示帧预算(ms)覆盖值；默认从 trace 的 VSync / FrameTimeline 推断
```

## Ordered execution

### TextureView 生产/消费信号概览

- ID: `textureview_signal_summary`
- Type: `atomic`
- SQL: [`../sql/textureview_producer_frame_timing/textureview_signal_summary.sql`](../sql/textureview_producer_frame_timing/textureview_signal_summary.sql)

```yaml
id: textureview_signal_summary
type: atomic
display:
  level: summary
  layer: overview
  title: TextureView / SurfaceTexture 信号概览
  columns:
  - name: signal_role
    label: 角色
    type: string
  - name: signal_type
    label: 信号类型
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: event_count
    label: 信号次数（非帧数）
    type: number
    format: compact
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
  - name: p95_dur_ms
    label: P95耗时
    type: duration
    format: duration_ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
  - name: evidence_scope
    label: 证据范围
    type: string
  - name: claim_boundary
    label: 结论边界
    type: string
save_as: textureview_signal_summary
```
### TextureView 事件流帧间隔

- ID: `textureview_producer_intervals`
- Type: `atomic`
- SQL: [`../sql/textureview_producer_frame_timing/textureview_producer_intervals.sql`](../sql/textureview_producer_frame_timing/textureview_producer_intervals.sql)

```yaml
id: textureview_producer_intervals
type: atomic
display:
  level: detail
  layer: list
  title: TextureView 事件流节奏缺口候选
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: interval_ns
  - name: interval_ns
    label: 间隔(ns)
    type: duration
    unit: ns
    hidden: true
  - name: interval_ms
    label: 帧间隔
    type: duration
    format: duration_ms
  - name: vsync_missed
    label: 疑似漏生产帧
    type: number
    format: compact
  - name: event_role
    label: 事件角色
    type: string
  - name: event_stream
    label: 事件流
    type: string
  - name: event_name
    label: 事件
    type: string
  - name: previous_event_name
    label: 前一事件
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: display_vsync_ms
    label: 显示 VSync
    type: duration
    format: duration_ms
  - name: stream_period_ms
    label: 事件流周期
    type: duration
    format: duration_ms
  - name: cadence_baseline_ms
    label: 节奏基线
    type: duration
    format: duration_ms
  - name: vsync_source
    label: VSync 来源
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
  - name: claim_boundary
    label: 结论边界
    type: string
  - name: rating
    label: 评级
    type: string
sql_fragments:
- fragments/vsync_config.sql
save_as: textureview_producer_intervals
```
## Output and evidence contract

```yaml
format: structured
```
