GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_idle_state_residency.skill.yaml
Source SHA-256: 7ca1a5633d514d72c2e841694bf0c3eb19be753350fdd1168e412761c8337eec
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# CPU Idle 驻留

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_idle_state_residency
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: CPU Idle 驻留
description: 每 CPU 各 idle 状态的驻留计数
icon: battery_saver
tags:
- cpu
- idle
- residency
- atomic
```

## Prerequisites

```yaml
modules:
- linux.cpu.idle
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

### Idle 驻留计数

- ID: `idle_residency`
- Type: `atomic`
- SQL: [`../sql/cpu_idle_state_residency/idle_residency.sql`](../sql/cpu_idle_state_residency/idle_residency.sql)

```yaml
id: idle_residency
type: atomic
display:
  level: detail
  layer: list
  title: CPU Idle 状态分布
  columns:
  - name: cpu
    label: CPU
    type: number
  - name: idle_state
    label: Idle 状态
    type: number
  - name: total_time_ms
    label: 驻留时长(ms)
    type: duration
    format: duration_ms
  - name: residency_pct
    label: 驻留占比(%)
    type: percentage
  - name: interval_count
    label: 区间数
    type: number
    format: compact
```
