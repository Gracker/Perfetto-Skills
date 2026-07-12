GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/rn_bridge_to_frame_jank.skill.yaml
Source SHA-256: d2cce13360dd218d1931638ebf4d69f3b01a43c9ae5c3470bb7c9ba5e3202311
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# RN Bridge 到帧卡顿关联

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: rn_bridge_to_frame_jank
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: RN Bridge 到帧卡顿关联
description: 关联 React Native old-arch Bridge/JS/UIManager 工作与掉帧帧窗口
icon: hub
tags:
- react_native
- rn
- bridge
- javascript
- frame
- jank
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - React Native
  - RN Bridge
  - BatchedBridge
  - JS 线程
  - RN 卡顿
  en:
  - react native
  - rn bridge
  - batchedbridge
  - js thread
  - rn jank
patterns:
- .*(React Native|RN).*(Bridge|JS|卡顿|掉帧).*
- .*(react native|rn).*(bridge|js|jank|frame).*
```

## Prerequisites

```yaml
required_tables:
- actual_frame_timeline_slice
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
```

## Ordered execution

### RN Bridge 与帧重叠

- ID: `rn_bridge_frame_overlap`
- Type: `atomic`
- SQL: [`../sql/rn_bridge_to_frame_jank/rn_bridge_frame_overlap.sql`](../sql/rn_bridge_to_frame_jank/rn_bridge_frame_overlap.sql)

```yaml
id: rn_bridge_frame_overlap
type: atomic
display:
  level: detail
  layer: list
  title: RN Bridge / JS 工作与掉帧帧重叠
  columns:
  - name: ts
    label: Bridge时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: Bridge耗时(ns)
    type: duration
    unit: ns
    hidden: true
  - name: bridge_dur_ms
    label: Bridge耗时
    type: duration
    format: duration_ms
  - name: phase
    label: 阶段
    type: string
  - name: slice_name
    label: Slice
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: overlapped_frames
    label: 重叠帧数
    type: number
    format: compact
  - name: janky_frames
    label: 掉帧重叠
    type: number
    format: compact
  - name: max_overlap_ms
    label: 最大重叠
    type: duration
    format: duration_ms
  - name: max_frame_dur_ms
    label: 最大帧耗时
    type: duration
    format: duration_ms
save_as: rn_bridge_frame_overlap
```
## Output and evidence contract

```yaml
format: structured
```
