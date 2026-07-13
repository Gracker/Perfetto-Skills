GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/gpu_power_state_analysis.skill.yaml
Source SHA-256: 0a4ae145d64ac7d9eddb15b2f73f8f209e360d4d06e87e8bb500751ee7162f6d
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
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
description: 分析 GPU 频率状态切换，识别降频压力与抖动
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
- name: transition_threshold_pct
  type: number
  required: false
  default: 15
  description: 判定升降频的百分比阈值
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
  label: 平均频率(MHz)
  type: number
- name: min_freq_mhz
  label: 最低频率(MHz)
  type: number
- name: max_freq_mhz
  label: 最高频率(MHz)
  type: number
- name: downshift_count
  label: 降频次数
  type: number
- name: upshift_count
  label: 升频次数
  type: number
- name: downshift_ratio_pct
  label: 降频占比
  type: percentage
  format: percentage
```
