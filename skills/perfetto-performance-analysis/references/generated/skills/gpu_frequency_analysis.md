GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/gpu_frequency_analysis.skill.yaml
Source SHA-256: 1d59af695d05776443586c0844c80e4355558779825f9f6befb83acc2b8338d0
# GPU 频率分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gpu_frequency_analysis
version: '1.0'
type: atomic
category: gpu
tier: B
```

## Metadata

```yaml
display_name: GPU 频率分析
description: 分析 GPU 频率变化（不采集 GPU 频率上限证据，不判定限频或温控）
icon: memory
tags:
- gpu
- frequency
- dvfs
- thermal
- atomic
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

## Query

Run [`../sql/gpu_frequency_analysis/query.sql`](../sql/gpu_frequency_analysis/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: overview
title: GPU 频率分析
columns:
- name: metric
  label: 指标
  type: string
- name: value
  label: 值
  type: string
- name: assessment
  label: 评估
  type: string
```
