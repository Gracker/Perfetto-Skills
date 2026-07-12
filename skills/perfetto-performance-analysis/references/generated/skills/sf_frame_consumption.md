GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/sf_frame_consumption.skill.yaml
Source SHA-256: 45c4f9d714bd602d37b6011a5c75d3aa1293dc5e685525319a2af173b801d580
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# SurfaceFlinger 帧消费分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: sf_frame_consumption
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: SurfaceFlinger 帧消费分析
description: 分析 SurfaceFlinger 消费帧的情况
icon: layers
tags:
- surfaceflinger
- frame
- consumption
- atomic
pipeline_aware: true
pipeline_aware_note: '多 layer 类型（SurfaceView/Multi-Window/Mixed/Flutter HC）时 SF 合成成本要归因到具体 layer。

  未来按 pipeline_id 切换 layer 维度的合成耗时分组 SQL。

  '
```

## Triggers

```yaml
keywords:
  zh:
  - SurfaceFlinger
  - SF 帧消费
  - 消费端
  - present
  - 显示节奏
  en:
  - surfaceflinger frame consumption
  - sf consumption
  - present cadence
patterns:
- .*(SurfaceFlinger|SF).*(消费|present|帧).*
- .*surfaceflinger.*(consumption|present|frame).*
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
- name: layer_name
  type: string
  required: false
```

## Ordered execution

### SF 帧消费统计

- ID: `sf_consumption_stats`
- Type: `atomic`
- SQL: [`../sql/sf_frame_consumption/sf_consumption_stats.sql`](../sql/sf_frame_consumption/sf_consumption_stats.sql)

```yaml
id: sf_consumption_stats
type: atomic
save_as: sf_consumption
```
## Output and evidence contract

```yaml
format: single_row
fields:
- name: total_consumed_frames
  type: integer
  description: SF 消费的总帧数
- name: actual_fps
  type: number
  description: 实际 FPS（基于消费端）
- name: median_fps
  type: number
  description: 中位数 FPS
- name: jank_rate
  type: number
  description: 掉帧率 %
```
