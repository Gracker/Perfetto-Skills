GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/battery_drain_rate_summary.skill.yaml
Source SHA-256: f5a1df9c8222d32c6942df42bb1bbde8dc81f44d1b7cd23ea41aed8897bda582
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 掉电速率摘要

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: battery_drain_rate_summary
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: 掉电速率摘要
description: 基于 battery counters 计算窗口掉电速率、电流/电压摘要和充电不可判定状态
icon: battery_alert
tags:
- battery
- drain
- current
- voltage
- power
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - 掉电速率
  - 电池电流
  - 电池电压
  - 充电
  - USB
  - battery drain
  en:
  - battery drain rate
  - current
  - voltage
  - charging
  - USB
patterns:
- .*(掉电|电池).*(速率|电流|电压).*
- .*battery.*(drain|current|voltage).*
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
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
```

## Ordered execution

### 掉电速率摘要

- ID: `drain_rate`
- Type: `atomic`
- SQL: [`../sql/battery_drain_rate_summary/drain_rate.sql`](../sql/battery_drain_rate_summary/drain_rate.sql)

```yaml
id: drain_rate
type: atomic
display:
  level: summary
  layer: overview
  title: 掉电速率摘要
  columns:
  - name: sample_count
    label: 样本数
    type: number
  - name: duration_sec
    label: 窗口时长(秒)
    type: number
    format: compact
  - name: capacity_delta_pct
    label: 电量变化(%)
    type: percentage
  - name: drain_pct_per_hour
    label: 掉电(%/h)
    type: number
    format: compact
  - name: charge_delta_uah
    label: 电荷变化(uAh)
    type: number
    format: compact
  - name: avg_current_ua
    label: 平均电流(uA)
    type: number
    format: compact
  - name: avg_voltage_uv
    label: 平均电压(uV)
    type: number
    format: compact
  - name: avg_power_mw
    label: 平均功率(mW)
    type: number
    format: compact
  - name: charging_state
    label: 充电状态
    type: string
  - name: source_level
    label: 数据来源
    type: string
```
## Output and evidence contract

```yaml
format: structured
```
