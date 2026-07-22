GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/flutter_scrolling_analysis.skill.yaml
Source SHA-256: 1948ff2572667b9c7ccba73cb1bc9334c36b3ae6f6ae78371b7c64e154421c72
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# Flutter 滑动分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: flutter_scrolling_analysis
version: '1.0'
type: composite
category: interaction
tier: S
```

## Metadata

```yaml
display_name: Flutter 滑动分析
description: Flutter 应用帧渲染分析：UI 线程 + Raster 线程 + 帧时序
icon: flutter
tags:
- flutter
- scrolling
- jank
- fps
- frames
```

## Prerequisites

```yaml
required_tables:
- actual_frame_timeline_slice
modules:
- android.frames.timeline
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: Flutter 应用包名
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒）
- name: vsync_period_ns
  type: number
  required: false
  description: VSync 周期（纳秒），默认 16666667 (60Hz)
```

## Context requirements

```yaml
- package
- vsync_period_ns
- refresh_rate_hz
```

## Ordered execution

### Flutter 帧概览

- ID: `flutter_frame_overview`
- Type: `atomic`
- SQL: [`../sql/flutter_scrolling_analysis/flutter_frame_overview.sql`](../sql/flutter_scrolling_analysis/flutter_frame_overview.sql)

```yaml
id: flutter_frame_overview
type: atomic
display:
  level: summary
  layer: overview
  title: Flutter 帧渲染概览
  format: table
save_as: overview
```
### Flutter 线程耗时

- ID: `flutter_thread_analysis`
- Type: `atomic`
- SQL: [`../sql/flutter_scrolling_analysis/flutter_thread_analysis.sql`](../sql/flutter_scrolling_analysis/flutter_thread_analysis.sql)

```yaml
id: flutter_thread_analysis
type: atomic
display:
  level: detail
  layer: list
  title: Flutter 线程耗时分布
  format: table
```
### Flutter 消费端掉帧检测

- ID: `flutter_consumer_jank`
- Type: `atomic`
- SQL: [`../sql/flutter_scrolling_analysis/flutter_consumer_jank.sql`](../sql/flutter_scrolling_analysis/flutter_consumer_jank.sql)

```yaml
id: flutter_consumer_jank
type: atomic
display:
  level: summary
  layer: overview
  title: Flutter 掉帧类型分布（消费端验证）
  format: table
  columns:
  - name: jank_type
    label: 掉帧类型
    type: string
  - name: count
    label: 帧数
    type: number
    format: compact
  - name: real_jank_count
    label: 实际掉帧
    type: number
    format: compact
  - name: hidden_jank_count
    label: 隐藏掉帧
    type: number
    format: compact
  - name: false_positive
    label: 假阳性
    type: number
  - name: avg_dur
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: responsibility
    label: 类型标签
    type: string
save_as: flutter_jank_stats
```
### Flutter 掉帧列表

- ID: `flutter_jank_frames`
- Type: `atomic`
- SQL: [`../sql/flutter_scrolling_analysis/flutter_jank_frames.sql`](../sql/flutter_scrolling_analysis/flutter_jank_frames.sql)

```yaml
id: flutter_jank_frames
type: atomic
display:
  level: detail
  layer: list
  title: Flutter 掉帧帧列表 (按严重程度排序)
  format: table
  columns:
  - name: ts
    type: timestamp
    clickAction: navigate_timeline
  - name: dur_ms
    type: duration
    format: duration_ms
  - name: jank_level
    type: string
  - name: frames_dropped
    type: number
save_as: jank_frames
```
### UI 线程长耗时

- ID: `flutter_ui_thread_long_slices`
- Type: `atomic`
- SQL: [`../sql/flutter_scrolling_analysis/flutter_ui_thread_long_slices.sql`](../sql/flutter_scrolling_analysis/flutter_ui_thread_long_slices.sql)

```yaml
id: flutter_ui_thread_long_slices
type: atomic
display:
  level: detail
  layer: list
  title: Flutter UI 线程 (1.ui) 长耗时 Slice
  format: table
  columns:
  - name: ts
    type: timestamp
    clickAction: navigate_timeline
  - name: dur_ms
    type: duration
    format: duration_ms
```
### Raster 线程长耗时

- ID: `flutter_raster_thread_long_slices`
- Type: `atomic`
- SQL: [`../sql/flutter_scrolling_analysis/flutter_raster_thread_long_slices.sql`](../sql/flutter_scrolling_analysis/flutter_raster_thread_long_slices.sql)

```yaml
id: flutter_raster_thread_long_slices
type: atomic
display:
  level: detail
  layer: list
  title: Flutter Raster 线程 (1.raster) 长耗时 Slice
  format: table
  columns:
  - name: ts
    type: timestamp
    clickAction: navigate_timeline
  - name: dur_ms
    type: duration
    format: duration_ms
```
