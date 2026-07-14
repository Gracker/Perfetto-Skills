GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/battery_charge_timeline.skill.yaml
Source SHA-256: f2c833e0011fe26b5fa5876a09017049993e4ccd8fb399900e18e730417a037b
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# 电池电量时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: battery_charge_timeline
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: 电池电量时间线
description: 电池电量/电压/电流采样时间序列
icon: battery_charging_full
tags:
- battery
- charge
- voltage
- current
- atomic
```

## Prerequisites

```yaml
modules:
- android.battery
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

### 电池采样序列

- ID: `battery_samples`
- Type: `atomic`
- SQL: [`../sql/battery_charge_timeline/battery_samples.sql`](../sql/battery_charge_timeline/battery_samples.sql)

```yaml
id: battery_samples
type: atomic
display:
  level: detail
  layer: list
  title: 电池电量/电压/电流
  columns:
  - name: ts
    label: 时间
    type: timestamp
  - name: capacity_pct
    label: 电量(%)
    type: percentage
  - name: charge_uah
    label: 电荷(μAh)
    type: number
    format: compact
  - name: voltage_uv
    label: 电压(μV)
    type: number
    format: compact
  - name: current_ua
    label: 电流(μA)
    type: number
    format: compact
```
