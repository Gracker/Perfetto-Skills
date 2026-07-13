GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/rn_fabric_render_jank.skill.yaml
Source SHA-256: fdfb43f4d0487f058bf09549e6a0be4d373503cd106e5e8344e77129265ead8a
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# RN Fabric/JSI 渲染卡顿

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: rn_fabric_render_jank
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: RN Fabric/JSI 渲染卡顿
description: 关联 React Native New Architecture 的 Fabric/JSI/Mounting 同步工作与掉帧帧窗口
icon: account_tree
tags:
- react_native
- rn
- fabric
- jsi
- turbo_module
- frame
- jank
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - RN Fabric
  - JSI
  - TurboModule
  - Fabric Mounting
  - RN 新架构卡顿
  en:
  - rn fabric
  - jsi
  - turbomodule
  - fabric mounting
  - new architecture jank
patterns:
- .*(Fabric|JSI|TurboModule).*(卡顿|掉帧|同步渲染).*
- .*(fabric|jsi|turbomodule).*(jank|frame|sync).*
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

### Fabric/JSI 与帧重叠

- ID: `fabric_frame_overlap`
- Type: `atomic`
- SQL: [`../sql/rn_fabric_render_jank/fabric_frame_overlap.sql`](../sql/rn_fabric_render_jank/fabric_frame_overlap.sql)

```yaml
id: fabric_frame_overlap
type: atomic
display:
  level: detail
  layer: list
  title: RN Fabric / JSI 同步工作与帧重叠
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 耗时(ns)
    type: duration
    unit: ns
    hidden: true
  - name: dur_ms
    label: 耗时
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
  - name: severity
    label: 严重程度
    type: string
save_as: fabric_frame_overlap
```
## Output and evidence contract

```yaml
format: structured
```
