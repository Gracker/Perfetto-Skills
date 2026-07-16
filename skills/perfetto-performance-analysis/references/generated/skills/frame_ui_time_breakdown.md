GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/frame_ui_time_breakdown.skill.yaml
Source SHA-256: e954401abb0cdd3049a98ff540b0dcb21f44e7008292d852ac5fdc4426d59fcd
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 每帧 UI 时间

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: frame_ui_time_breakdown
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: 每帧 UI 时间
description: 每帧 UI thread 总耗时
icon: view_in_ar
tags:
- frame
- ui_time
- main_thread
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - UI 时间
  - 主线程帧耗时
  - app vsync delay
  - 帧 UI 拆解
  en:
  - frame ui time
  - main thread frame time
  - app vsync delay
patterns:
- .*(UI|主线程).*帧.*(耗时|时间).*
- .*frame.*(ui|main thread|vsync delay).*
```

## Prerequisites

```yaml
modules:
- android.frames.per_frame_metrics
```

## Ordered execution

### 每帧 UI 耗时

- ID: `ui_time`
- Type: `atomic`
- SQL: [`../sql/frame_ui_time_breakdown/ui_time.sql`](../sql/frame_ui_time_breakdown/ui_time.sql)

```yaml
id: ui_time
type: atomic
display:
  level: detail
  layer: list
  title: Frame × UI Thread 时长
  columns:
  - name: frame_id
    label: Frame
    type: number
  - name: ui_time_ms
    label: UI 时间(ms)
    type: duration
    format: duration_ms
```
