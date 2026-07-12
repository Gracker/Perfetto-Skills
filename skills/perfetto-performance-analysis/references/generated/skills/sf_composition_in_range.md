GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/sf_composition_in_range.skill.yaml
Source SHA-256: d3a3ab37e6a618fdebe97162b06b53a9f787a43fbeccbf22790bc04e73d8306d
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# SF 合成分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: sf_composition_in_range
version: '1.0'
type: atomic
category: framework
tier: B
```

## Metadata

```yaml
display_name: SF 合成分析
description: 分析 SurfaceFlinger 合成延迟
icon: layers
tags:
- surfaceflinger
- composition
- framework
- atomic
pipeline_aware: true
pipeline_aware_note: 'SF 合成时多 layer 类型（SurfaceView/Mixed/HC overlay）的归因 SQL 与单 layer 类型不同。

  未来按 pipeline_id + layer_count 切换合成成本分解 SQL。

  '
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
```

## Query

Run [`../sql/sf_composition_in_range/query.sql`](../sql/sf_composition_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: SurfaceFlinger 合成
columns:
- name: composition_type
  label: 合成阶段
  type: string
- name: count
  label: 次数
  type: number
- name: total_ms
  label: 总耗时
  type: duration
  format: duration_ms
- name: avg_ms
  label: 平均耗时
  type: duration
  format: duration_ms
- name: max_ms
  label: 最大耗时
  type: duration
  format: duration_ms
```
