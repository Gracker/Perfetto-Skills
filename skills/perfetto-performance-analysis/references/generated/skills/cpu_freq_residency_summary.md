GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_freq_residency_summary.skill.yaml
Source SHA-256: 574b201a6ed4593061204a5cda42d112cb63665150c965bf038ba6a7a075daca
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# CPU 高频驻留摘要

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_freq_residency_summary
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: CPU 高频驻留摘要
description: 按大小核/频点桶统计窗口内 CPU 频率驻留和高频占比
icon: speed
tags:
- cpu
- frequency
- residency
- power
- dvfs
- atomic
```

## Prerequisites

```yaml
modules:
- linux.cpu.frequency
- android.cpu.cluster_type
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

### CPU 频率驻留

- ID: `freq_residency`
- Type: `atomic`
- SQL: [`../sql/cpu_freq_residency_summary/freq_residency.sql`](../sql/cpu_freq_residency_summary/freq_residency.sql)

```yaml
id: freq_residency
type: atomic
display:
  level: summary
  layer: list
  title: CPU 高频驻留
  columns:
  - name: cluster_type
    label: Cluster
    type: string
  - name: cpu_count
    label: CPU 数
    type: number
  - name: total_residency_sec
    label: 总驻留(秒)
    type: number
    format: compact
  - name: high_freq_residency_sec
    label: 高频驻留(秒)
    type: number
    format: compact
  - name: high_freq_ratio_pct
    label: 高频占比(%)
    type: percentage
  - name: weighted_avg_freq_mhz
    label: 加权平均频率(MHz)
    type: number
    format: compact
  - name: max_freq_mhz
    label: 最高频率(MHz)
    type: number
    format: compact
```
## Output and evidence contract

```yaml
format: structured
```
