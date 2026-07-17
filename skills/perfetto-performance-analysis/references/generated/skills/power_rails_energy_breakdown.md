GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/power_rails_energy_breakdown.skill.yaml
Source SHA-256: 6aaff1c3c000fd17b55820ae6849ffcf6d24beb72dd5a902f08144738181563f
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
# Power Rails 实测能耗分解

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: power_rails_energy_breakdown
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: Power Rails 实测能耗分解
description: 基于 android.power_rails 统计窗口内 rail 能耗、平均功率和数据来源等级
icon: battery_full
tags:
- power
- rails
- odpm
- energy
- measurement
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - power rails
  - rail 能耗
  - ODPM
  - 实测功耗
  - 子系统能耗
  en:
  - power rails
  - rail energy
  - ODPM
  - measured power
  - subsystem energy
patterns:
- .*(power rails|rail energy|ODPM).*
- .*(rail|子系统).*(能耗|功耗).*
```

## Prerequisites

```yaml
modules:
- android.power_rails
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
- name: top_n
  type: number
  required: false
  default: 30
  description: 返回前 N 条 rail
```

## Ordered execution

### Power Rail 实测能耗

- ID: `rail_energy`
- Type: `atomic`
- SQL: [`../sql/power_rails_energy_breakdown/rail_energy.sql`](../sql/power_rails_energy_breakdown/rail_energy.sql)

```yaml
id: rail_energy
type: atomic
display:
  level: summary
  layer: list
  title: Power Rail 实测能耗
  columns:
  - name: power_rail_name
    label: Rail
    type: string
  - name: subsystem_name
    label: 子系统
    type: string
  - name: raw_power_rail_name
    label: Raw Rail
    type: string
  - name: energy_uws
    label: 能耗(uWs)
    type: number
    format: compact
  - name: energy_mwh
    label: 能耗(mWh)
    type: number
    format: compact
  - name: avg_power_mw
    label: 平均功率(mW)
    type: number
    format: compact
  - name: sample_coverage_pct
    label: 采样覆盖(%)
    type: percentage
  - name: source_level
    label: 数据来源
    type: string
```
## Output and evidence contract

```yaml
format: structured
```
