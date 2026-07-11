GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/frame_overrun_summary.skill.yaml
Source SHA-256: 2ef5423c5d7600d720f049fe458bccf4b167e2319a423fa99c754d3b4e6de88f
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# Frame Overrun 汇总

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: frame_overrun_summary
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: Frame Overrun 汇总
description: 超 budget 的帧（jank 候选）
icon: warning
tags:
- frame
- overrun
- jank
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - frame overrun
  - 帧超时
  - 超预算
  - 掉帧汇总
  en:
  - frame overrun
  - frame budget
  - overrun summary
  - dropped frame
patterns:
- .*(overrun|budget).*frame.*
- .*(帧|掉帧).*(超时|超预算).*
```

## Prerequisites

```yaml
modules:
- android.frames.per_frame_metrics
```

## Ordered execution

### Overrun 帧列表

- ID: `overrun_frames`
- Type: `atomic`
- SQL: [`../sql/frame_overrun_summary/overrun_frames.sql`](../sql/frame_overrun_summary/overrun_frames.sql)

```yaml
id: overrun_frames
type: atomic
display:
  level: detail
  layer: list
  title: 超 budget 帧列表
  columns:
  - name: frame_id
    label: Frame ID
    type: number
  - name: ts
    label: 时间
    type: timestamp
  - name: dur_ms
    label: 实际时长(ms)
    type: duration
    format: duration_ms
  - name: overrun_ms
    label: 超额(ms)
    type: duration
    format: duration_ms
```
