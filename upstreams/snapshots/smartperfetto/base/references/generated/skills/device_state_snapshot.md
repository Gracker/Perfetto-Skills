GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/device_state_snapshot.skill.yaml
Source SHA-256: 886bf69ae41b697f5c80cad4e1787cc5198233e15f65cb3c9cb3d382ca3b3655
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d
# 设备环境状态快照

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: device_state_snapshot
version: '2.0'
type: composite
category: system_context
tier: B
```

## Metadata

```yaml
display_name: 设备环境状态快照
description: 采集 trace 期间的设备环境信息（屏幕、电量、温度、CPU、内存、idle 窗口等）
icon: devices
tags:
- device
- state
- environment
- context
- composite
```

## Prerequisites

```yaml
required_tables:
- slice
- counter
- counter_track
```

## Inputs

```yaml
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

### 设备环境快照

- ID: `environment_snapshot`
- Type: `atomic`
- SQL: [`../sql/device_state_snapshot/environment_snapshot.sql`](../sql/device_state_snapshot/environment_snapshot.sql)

```yaml
id: environment_snapshot
type: atomic
display:
  level: summary
  layer: overview
  title: 设备环境状态
  columns:
  - name: metric
    label: 指标
    type: string
  - name: value
    label: 值
    type: string
  - name: ts
    label: 时间戳
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
save_as: environment_snapshot
synthesize:
  role: overview
  fields:
  - key: metric
    label: 指标
  - key: value
    label: 值
```
### Idle 窗口摘要

- ID: `idle_window_summary`
- Type: `atomic`
- SQL: [`../sql/device_state_snapshot/idle_window_summary.sql`](../sql/device_state_snapshot/idle_window_summary.sql)

```yaml
id: idle_window_summary
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: Idle / 空闲窗口
  columns:
  - name: start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: end_ts
    label: 结束
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur_ms
    label: 时长
    type: duration
    unit: ms
  - name: source
    label: 来源
    type: string
save_as: idle_window_summary
synthesize:
  role: list
  fields:
  - key: dur_ms
    label: Idle 时长
    format: '{{value}} ms'
```
## Output and evidence contract

```yaml
format: structured
```
