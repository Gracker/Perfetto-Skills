GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_gpu_work_period_track.skill.yaml
Source SHA-256: 8a497f4a41658ca2975e94bec53ccda4461bdd56763195ae3a57f32807c97017
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# GPU Work Period

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_gpu_work_period_track
version: '1.0'
type: atomic
category: gpu
tier: B
```

## Metadata

```yaml
display_name: GPU Work Period
description: GPU 实际工作区间（功耗模型前置数据）
icon: memory
tags:
- gpu
- work_period
- power
- wattson
- atomic
```

## Prerequisites

```yaml
modules:
- android.gpu.work_period
```

## Ordered execution

### GPU 工作区间

- ID: `gpu_work`
- Type: `atomic`
- SQL: [`../sql/android_gpu_work_period_track/gpu_work.sql`](../sql/android_gpu_work_period_track/gpu_work.sql)

```yaml
id: gpu_work
type: atomic
display:
  level: detail
  layer: list
  title: GPU Work Period 区间
  columns:
  - name: ts
    label: 起始
    type: timestamp
  - name: dur_ms
    label: 时长(ms)
    type: duration
    format: duration_ms
  - name: uid
    label: UID
    type: number
```
