GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/gpu_freq_in_range.skill.yaml
Source SHA-256: 6b78313b5cf0ad8f7be13fe1f517af3abdf7bce59f14197d95242dbca036c4ba
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# GPU 频率分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gpu_freq_in_range
version: '1.0'
type: atomic
category: gpu
tier: B
```

## Metadata

```yaml
display_name: GPU 频率分析
description: 分析 GPU 频率变化情况
icon: speed
tags:
- gpu
- frequency
- atomic
```

## Prerequisites

```yaml
modules:
- android.gpu.frequency
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns，可选)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns，可选)
- name: low_freq_threshold_pct
  type: number
  required: false
  default: 40
  description: 低频阈值百分比 (相对最大频率，默认 40%)
```

## Query

Run [`../sql/gpu_freq_in_range/query.sql`](../sql/gpu_freq_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: GPU 频率
columns:
- name: gpu_id
  label: GPU
  type: number
- name: avg_freq_mhz
  label: 平均频率
  type: number
- name: max_freq_mhz
  label: 最大频率
  type: number
- name: min_freq_mhz
  label: 最小频率
  type: number
- name: freq_changes
  label: 变频次数
  type: number
- name: low_freq_pct
  label: 低频占比
  type: percentage
  format: percentage
```
