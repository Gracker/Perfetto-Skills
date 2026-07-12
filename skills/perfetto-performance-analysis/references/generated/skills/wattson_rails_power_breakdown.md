GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/wattson_rails_power_breakdown.skill.yaml
Source SHA-256: 8214b9e8c26e8130521fe0d2665da06cf7fa7d139bddbcd0a6f83543d3c09bdb
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# Power Rails 能耗分解

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: wattson_rails_power_breakdown
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: Power Rails 能耗分解
description: 按 Wattson 子系统统计估算能耗（mWs）和平均功率（mW）
icon: battery_full
tags:
- power
- wattson
- rails
- energy
- atomic
```

## Prerequisites

```yaml
modules:
- wattson.aggregation
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
  default: 20
  description: 返回前 N 条 rail（按能耗排序）
```

## Ordered execution

### Power Rails 能耗聚合

- ID: `rails_aggregation`
- Type: `atomic`
- SQL: [`../sql/wattson_rails_power_breakdown/rails_aggregation.sql`](../sql/wattson_rails_power_breakdown/rails_aggregation.sql)

```yaml
id: rails_aggregation
type: atomic
display:
  level: detail
  layer: list
  title: 按 Rail 的能耗与峰值功率
  columns:
  - name: subsystem
    label: 子系统
    type: string
  - name: breakdown_type
    label: 分解类型
    type: string
  - name: component_id
    label: 组件
    type: string
  - name: total_energy_mws
    label: 总能耗(mWs)
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
  - name: source_level
    label: 数据来源
    type: string
```
