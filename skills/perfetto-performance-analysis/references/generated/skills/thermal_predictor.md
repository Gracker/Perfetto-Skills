GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/thermal_predictor.skill.yaml
Source SHA-256: 16bb6ec7bc5e0769d25f1b2b46ed3a8d7d71648c6c6ae67e745ef86966aaa7ef
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 热控风险预测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: thermal_predictor
version: '1.0'
type: atomic
category: thermal
tier: B
```

## Metadata

```yaml
display_name: 热控风险预测
description: 基于 CPU 频率趋势预测热限频风险
icon: thermostat
tags:
- thermal
- throttling
- prediction
- cpu
```

## Triggers

```yaml
keywords:
  zh:
  - 热风险
  - 热控
  - 限频预测
  - 温度趋势
  en:
  - thermal risk
  - thermal predictor
  - throttling prediction
patterns:
- .*thermal.*(predict|risk).*
- .*(热控|限频).*(预测|风险).*
```

## Prerequisites

```yaml
required_tables:
- counter
- cpu_counter_track
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 分析结束时间戳(ns)
- name: high_drop_threshold_pct
  type: number
  required: false
  default: 30
  description: 平均降频高风险阈值（%）
- name: medium_drop_threshold_pct
  type: number
  required: false
  default: 15
  description: 平均降频中风险阈值（%）
- name: high_core_ratio_threshold_pct
  type: number
  required: false
  default: 50
  description: 限频核心占比高风险阈值（%）
- name: medium_core_ratio_threshold_pct
  type: number
  required: false
  default: 25
  description: 限频核心占比中风险阈值（%）
- name: core_drop_threshold_pct
  type: number
  required: false
  default: 30
  description: 单核心疑似限频判定阈值（%）
```

## Query

Run [`../sql/thermal_predictor/query.sql`](../sql/thermal_predictor/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: summary
layer: overview
title: 热控预测
columns:
- name: avg_start_freq_mhz
  label: 区间初段频率
  type: number
- name: avg_end_freq_mhz
  label: 区间末段频率
  type: number
- name: avg_drop_pct
  label: 平均降幅
  type: percentage
  format: percentage
- name: throttled_core_ratio_pct
  label: 疑似限频核心占比
  type: percentage
  format: percentage
- name: thermal_risk
  label: 热控风险
  type: string
- name: prediction
  label: 预测
  type: string
```
