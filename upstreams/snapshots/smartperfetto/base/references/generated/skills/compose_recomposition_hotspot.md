GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
Source SHA-256: 2895ae93d263a1097b752875bc22c0e4521e6f96b6ad4feb319da03a76a0d59b
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# Compose 重组热点检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: compose_recomposition_hotspot
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: Compose 重组热点检测
description: 检测 Jetpack Compose 重组热点：过多或过慢的 Recomposition
icon: auto_fix_high
tags:
- compose
- recomposition
- jetpack
- performance
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - Compose
  - 重组
  - 重组热点
  - CompositionLocal
  - Jetpack Compose
  en:
  - compose
  - recomposition
  - recomposition hotspot
  - CompositionLocal
patterns:
- .*[Cc]ompose.*(recomposition|重组).*
- .*(重组|CompositionLocal).*
```

## Prerequisites

```yaml
required_tables:
- slice
- thread_track
- thread
- process
modules:
- android.frames.timeline
- slices.with_context
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标进程名（支持 GLOB）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
```

## Ordered execution

### FrameTimeline 可用性检测

- ID: `frame_timeline_check`
- Type: `atomic`
- SQL: [`../sql/compose_recomposition_hotspot/frame_timeline_check.sql`](../sql/compose_recomposition_hotspot/frame_timeline_check.sql)

```yaml
id: frame_timeline_check
type: atomic
display: false
save_as: frame_timeline
```
### 重组概览

- ID: `recomposition_overview`
- Type: `atomic`
- SQL: [`../sql/compose_recomposition_hotspot/recomposition_overview.sql`](../sql/compose_recomposition_hotspot/recomposition_overview.sql)

```yaml
id: recomposition_overview
type: atomic
display:
  level: summary
  layer: overview
  title: Compose 重组概览
  columns:
  - name: slice_name
    label: Slice 名称
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
  - name: rating
    label: 评级
    type: string
save_as: recomposition_overview
```
### 慢重组

- ID: `slow_recompositions`
- Type: `atomic`
- SQL: [`../sql/compose_recomposition_hotspot/slow_recompositions.sql`](../sql/compose_recomposition_hotspot/slow_recompositions.sql)

```yaml
id: slow_recompositions
type: atomic
display:
  level: detail
  layer: list
  title: 慢重组事件（>8ms）
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: slice_name
    label: Slice 名称
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
  - name: dur_ns
    label: 耗时(ns)
    type: duration
    unit: ns
    hidden: true
  - name: severity
    label: 严重程度
    type: string
save_as: slow_recompositions
```
### 重组频率

- ID: `composition_frequency`
- Type: `atomic`
- SQL: [`../sql/compose_recomposition_hotspot/composition_frequency.sql`](../sql/compose_recomposition_hotspot/composition_frequency.sql)

```yaml
id: composition_frequency
type: atomic
display:
  level: detail
  layer: list
  title: 重组频率（每秒）
  columns:
  - name: window_ts
    label: 时间窗口
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: process_name
    label: 进程
    type: string
  - name: recomposition_count
    label: 重组次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 窗口总耗时
    type: duration
    format: duration_ms
  - name: status
    label: 状态
    type: string
save_as: composition_frequency
```
### 重组与帧重叠

- ID: `recomposition_frame_overlap`
- Type: `atomic`
- SQL: [`../sql/compose_recomposition_hotspot/recomposition_frame_overlap.sql`](../sql/compose_recomposition_hotspot/recomposition_frame_overlap.sql)

```yaml
id: recomposition_frame_overlap
type: atomic
display:
  level: detail
  layer: list
  title: 导致掉帧风险的重组窗口
  columns:
  - name: ts
    label: 重组时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 重组耗时(ns)
    type: duration
    unit: ns
    hidden: true
  - name: recomposition_ms
    label: 重组耗时
    type: duration
    format: duration_ms
  - name: slice_name
    label: Slice
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: frame_id
    label: 帧 ID
    type: string
  - name: frame_dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
  - name: jank_type
    label: Jank 类型
    type: string
  - name: overlap_ms
    label: 重叠耗时
    type: duration
    format: duration_ms
  - name: severity
    label: 严重程度
    type: string
save_as: recomposition_frame_overlap
condition: frame_timeline.data[0]?.has_frame_timeline === 1
```
## Output and evidence contract

```yaml
format: structured
```
