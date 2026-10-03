GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/gpu_power_state_analysis.skill.yaml
Source SHA-256: 871f3507060112eb0aba2d1328f0c1c47a6e70c5865bb46d16ac0ff9ef8436bc
# GPU 功耗状态分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gpu_power_state_analysis
version: '1.0'
type: atomic
category: gpu
tier: B
```

## Metadata

```yaml
display_name: GPU 功耗状态分析
description: 分析 GPU 频率状态切换，识别频率下调与抖动
icon: bolt
tags:
- gpu
- power
- dvfs
- thermal
```

## Triggers

```yaml
keywords:
  zh:
  - GPU
  - 功耗
  - 降频
  - DVFS
  - 热控
  en:
  - gpu
  - power
  - downshift
  - dvfs
  - thermal
patterns:
- .*gpu.*(power|dvfs|freq).*
- .*(降频|功耗|热控).*gpu.*
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
- name: transition_threshold_pct
  type: number
  required: false
  default: 15
  description: 判定频率上调或下调的百分比阈值
```

## Query

Run [`../sql/gpu_power_state_analysis/query.sql`](../sql/gpu_power_state_analysis/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: GPU 功耗状态
columns:
- name: gpu_id
  label: GPU
  type: number
- name: samples
  label: 采样数
  type: number
- name: avg_freq_mhz
  label: 运行时平均频率(MHz)
  type: number
- name: min_freq_mhz
  label: 最低频率(MHz)
  type: number
- name: max_freq_mhz
  label: 最高频率(MHz)
  type: number
- name: downshift_count
  label: 频率下调次数
  type: number
- name: upshift_count
  label: 升频次数
  type: number
- name: downshift_ratio_pct
  label: 频率下调占比
  type: percentage
  format: percentage
- name: off_pct
  label: GPU 关闭占比
  type: percentage
  format: percentage
```
