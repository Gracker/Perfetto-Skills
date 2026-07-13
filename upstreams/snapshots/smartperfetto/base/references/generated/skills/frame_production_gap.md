GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/frame_production_gap.skill.yaml
Source SHA-256: f533dbd058eb314ef6dc1c8e1517275fb7432c17d5f0c2e136536a0c9a26acf2
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# 帧生产 Gap 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: frame_production_gap
version: '1.0'
type: composite
category: diagnostics
tier: A
```

## Metadata

```yaml
display_name: 帧生产 Gap 分析
description: 检测帧间隙（缺帧）并分析 UI Thread/RenderThread 在 gap 期间的活动状态
icon: broken_image
tags:
- frame
- gap
- missing
- production
- diagnostics
pipeline_aware: true
pipeline_aware_note: '"活动状态"分类当前是 pipeline-agnostic（UI Thread + RenderThread）。

  未来按 pipeline_id 切换：

  - Flutter: 看 1.ui + 1.raster 双线程活动

  - Game: 看 GameThread + RenderThread + RHIThread 三线程

  - WebView Functor: 看宿主 RT + Chromium CrRendererMain 双链路

  '
```

## Prerequisites

```yaml
required_tables:
- actual_frame_timeline_slice
- slice
- thread
- process
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
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: pipeline_id
  type: string
  required: false
  description: 'Pipeline ID (Phase F: pipeline-aware optional input)'
- name: min_gap_vsync
  type: number
  required: false
  description: 最小 gap 阈值（VSync 倍数，默认 1.5）
```

## Ordered execution

### 帧 Gap 概览

- ID: `gap_summary`
- Type: `atomic`
- SQL: [`../sql/frame_production_gap/gap_summary.sql`](../sql/frame_production_gap/gap_summary.sql)

```yaml
id: gap_summary
type: atomic
display:
  level: summary
  layer: overview
  title: 帧生产 Gap 概览
  columns:
  - name: total_frames
    label: 总帧数
    type: number
  - name: total_gaps
    label: Gap 数
    type: number
  - name: ui_no_frame_count
    label: UI无帧
    type: number
  - name: rt_no_drawframe_count
    label: RT无DrawFrame
    type: number
  - name: sf_backpressure_count
    label: SF背压
    type: number
  - name: max_gap_ms
    label: 最长Gap
    type: duration
    format: duration_ms
save_as: gap_overview
```
### 帧 Gap 列表

- ID: `gap_list`
- Type: `atomic`
- SQL: [`../sql/frame_production_gap/gap_list.sql`](../sql/frame_production_gap/gap_list.sql)

```yaml
id: gap_list
type: atomic
display:
  level: detail
  layer: list
  title: 帧 Gap 列表
  columns:
  - name: gap_start
    label: Gap 起始
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: gap_ns
  - name: gap_ns
    label: Gap 时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: gap_ms
    label: Gap 时长
    type: duration
    format: duration_ms
  - name: gap_vsync_count
    label: 跳过 VSync 数
    type: number
  - name: gap_type
    label: Gap 类型
    type: string
  - name: doframe_count
    label: doFrame 数
    type: number
  - name: drawframe_count
    label: DrawFrame 数
    type: number
  - name: before_frame_id
    label: 前帧 ID
    type: string
  - name: after_frame_id
    label: 后帧 ID
    type: string
save_as: gap_list
```
