GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cache_miss_impact.skill.yaml
Source SHA-256: f98a68d85159deab48eb38133d87b1e7a9fc61e91b4b659e2210997d60da51b1
Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49
# 缓存未命中影响

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cache_miss_impact
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: 缓存未命中影响
description: 统计 cache-miss 计数器并评估波动
icon: memory
tags:
- cpu
- cache
- perf_event
- counters
```

## Triggers

```yaml
keywords:
  zh:
  - 缓存未命中
  - cache miss
  - MPKI
  - L3
  - 缓存瓶颈
  en:
  - cache miss
  - mpki
  - l3 cache
  - cache bottleneck
patterns:
- .*cache.*(miss|mpki).*
- .*(缓存|L3).*(未命中|瓶颈).*
```

## Prerequisites

```yaml
required_tables:
- counter
- counter_track
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
- name: high_impact_threshold
  type: number
  required: false
  default: 500000
  description: 高影响阈值（平均增量）
- name: medium_impact_threshold
  type: number
  required: false
  default: 100000
  description: 中影响阈值（平均增量）
```

## Query

Run [`../sql/cache_miss_impact/query.sql`](../sql/cache_miss_impact/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 缓存未命中
columns:
- name: counter_name
  label: 计数器
  type: string
- name: samples
  label: 样本数
  type: number
- name: total_miss_delta
  label: 累计增量
  type: number
  format: compact
- name: avg_miss_delta
  label: 平均增量
  type: number
  format: compact
- name: peak_miss_delta
  label: 峰值增量
  type: number
  format: compact
- name: impact_level
  label: 影响等级
  type: string
```
