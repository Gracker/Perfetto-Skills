GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/app_frame_production.skill.yaml
Source SHA-256: c8e21c57ef149119c22d8a07d0dd4abed6c9b41b2a7542f8ed748adadb10621b
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# 应用帧生产分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: app_frame_production
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: 应用帧生产分析
description: 分析应用主线程的帧生产情况
icon: movie
tags:
- frame
- production
- app
- atomic
pipeline_aware: true
pipeline_aware_note: '"App 帧生产"在双/三线程时归因不同：Flutter 1.ui+1.raster；Game GameThread+RenderThread+RHI；

  RN mqt_js→Bridge/JSI→main。未来按 pipeline_id 切换主线程过滤 SQL。

  '
```

## Triggers

```yaml
keywords:
  zh:
  - 应用帧
  - 帧生产
  - 生产端
  - doFrame
  - 帧耗时
  en:
  - app frame
  - frame production
  - producer frame
  - doFrame
patterns:
- .*(应用帧|帧生产|生产端).*
- .*(app|producer).*(frame|production).*
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
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
```

## Ordered execution

### 应用帧生产统计

- ID: `app_production_stats`
- Type: `atomic`
- SQL: [`../sql/app_frame_production/app_production_stats.sql`](../sql/app_frame_production/app_production_stats.sql)

```yaml
id: app_production_stats
type: atomic
display:
  level: summary
  format: table
  columns:
  - name: total_produced_frames
    label: 总帧数
    type: number
    format: compact
  - name: duration_ms
    label: 持续时间
    type: duration
    format: duration_ms
  - name: on_time_frames
    label: 按时帧
    type: number
    format: compact
  - name: janky_frames
    label: 掉帧数
    type: number
    format: compact
  - name: app_jank_rate
    label: 掉帧率
    type: percentage
  - name: production_fps
    label: 生产 FPS
    type: number
  - name: expected_fps
    label: 期望 FPS
    type: number
  - name: avg_frame_dur_ms
    label: 平均帧耗时
    type: duration
    format: duration_ms
  - name: max_frame_dur_ms
    label: 最大帧耗时
    type: duration
    format: duration_ms
save_as: app_production
```
