GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/battery_doze_state_timeline.skill.yaml
Source SHA-256: 76538da9dab1b6f5e68441be298de8fa40633dbe1e8b0cf79d547d49c1f1e4a1
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d
# Doze 休眠状态时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: battery_doze_state_timeline
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: Doze 休眠状态时间线
description: Deep/Light idle 区间时间线
icon: bedtime
tags:
- doze
- idle
- battery
- power
- atomic
```

## Prerequisites

```yaml
modules:
- android.battery.doze
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
```

## Ordered execution

### Deep Idle 区间

- ID: `deep_idle_intervals`
- Type: `atomic`
- SQL: [`../sql/battery_doze_state_timeline/deep_idle_intervals.sql`](../sql/battery_doze_state_timeline/deep_idle_intervals.sql)

```yaml
id: deep_idle_intervals
type: atomic
display:
  level: detail
  layer: list
  title: Deep Idle 时间段
  columns:
  - name: ts
    label: 起始
    type: timestamp
  - name: dur_sec
    label: 时长(秒)
    type: duration
    format: compact
```
### Light Idle 区间

- ID: `light_idle_intervals`
- Type: `atomic`
- SQL: [`../sql/battery_doze_state_timeline/light_idle_intervals.sql`](../sql/battery_doze_state_timeline/light_idle_intervals.sql)

```yaml
id: light_idle_intervals
type: atomic
display:
  level: detail
  layer: list
  title: Light Idle 时间段
  columns:
  - name: ts
    label: 起始
    type: timestamp
  - name: dur_sec
    label: 时长(秒)
    type: duration
    format: compact
```
