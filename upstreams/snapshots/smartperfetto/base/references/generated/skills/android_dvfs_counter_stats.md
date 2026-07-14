GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_dvfs_counter_stats.skill.yaml
Source SHA-256: cf8599903da332db1aff2c03d179ffd4c5dd3ecd90fed3c66e1aafa3d74df84a
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# DVFS Counter 统计

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_dvfs_counter_stats
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: DVFS Counter 统计
description: CPU/GPU/DDR 频率统计（min/max/avg）
icon: tune
tags:
- dvfs
- freq
- cpu
- gpu
- atomic
```

## Prerequisites

```yaml
modules:
- android.dvfs
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

### DVFS 频率统计

- ID: `dvfs_stats`
- Type: `atomic`
- SQL: [`../sql/android_dvfs_counter_stats/dvfs_stats.sql`](../sql/android_dvfs_counter_stats/dvfs_stats.sql)

```yaml
id: dvfs_stats
type: atomic
display:
  level: detail
  layer: list
  title: DVFS Counter 统计
  columns:
  - name: name
    label: Counter
    type: string
  - name: min
    label: 最小
    type: number
    format: compact
  - name: max
    label: 最大
    type: number
    format: compact
  - name: wgt_avg
    label: 加权平均
    type: number
    format: compact
  - name: observed_sec
    label: 观测时长(秒)
    type: number
    format: compact
```
