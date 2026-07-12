GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/wattson_app_startup_power.skill.yaml
Source SHA-256: 306e55087c67e9f4fe2d3c6bf37e5372a3ed7019c0470eb97e07921adf210f1f
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# 应用启动期能耗

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: wattson_app_startup_power
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: 应用启动期能耗
description: 每次应用启动期间的总能耗（mWs）
icon: rocket_launch
tags:
- power
- wattson
- startup
- energy
- atomic
```

## Prerequisites

```yaml
modules:
- wattson.windows
- wattson.aggregation
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名 GLOB（可选）
```

## Ordered execution

### 启动期能耗列表

- ID: `startup_power`
- Type: `atomic`
- SQL: [`../sql/wattson_app_startup_power/startup_power.sql`](../sql/wattson_app_startup_power/startup_power.sql)

```yaml
id: startup_power
type: atomic
display:
  level: detail
  layer: list
  title: 应用启动能耗
  columns:
  - name: package
    label: 包名
    type: string
  - name: window_ts
    label: 起始时间
    type: timestamp
  - name: dur_ms
    label: 启动时长(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: total_energy_mws
    label: 总能耗(mWs)
    type: number
    format: compact
  - name: energy_mwh
    label: 能耗(mWh)
    type: number
    format: compact
  - name: source_level
    label: 数据来源
    type: string
```
