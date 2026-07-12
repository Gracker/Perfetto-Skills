GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_time_per_frame.skill.yaml
Source SHA-256: e9ca59dce47fb056113061c19ea44122bff0110e4f6206e0183f65bd96667e1b
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# 每帧 CPU 时间

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_time_per_frame
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: 每帧 CPU 时间
description: 每帧渲染期间该应用 CPU 累计活跃时长
icon: schedule
tags:
- frame
- cpu
- time_per_frame
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - 逐帧 CPU
  - 每帧 CPU
  - CPU 时间
  - 帧 CPU
  en:
  - per-frame cpu
  - frame cpu time
  - cpu per frame
patterns:
- .*(逐帧|每帧).*CPU.*
- .*(frame|per-frame).*cpu.*
```

## Prerequisites

```yaml
modules:
- android.frames.per_frame_metrics
```

## Ordered execution

### 每帧 CPU 时间

- ID: `cpu_time`
- Type: `atomic`
- SQL: [`../sql/cpu_time_per_frame/cpu_time.sql`](../sql/cpu_time_per_frame/cpu_time.sql)

```yaml
id: cpu_time
type: atomic
display:
  level: detail
  layer: list
  title: Frame × CPU 时间
  columns:
  - name: frame_id
    label: Frame
    type: number
  - name: cpu_time_ms
    label: CPU 时间(ms)
    type: duration
    format: duration_ms
```
