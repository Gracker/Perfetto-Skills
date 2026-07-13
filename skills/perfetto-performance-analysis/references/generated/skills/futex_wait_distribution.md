GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/futex_wait_distribution.skill.yaml
Source SHA-256: b4995afc55c08909120af15f468a3cfe33d21ec3543ae7509296c2f7dec683fd
Source commit: 68b113e0355716255af357e8396cd71c71e11d97
# Futex 等待分布

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: futex_wait_distribution
version: '1.0'
type: atomic
category: lock
tier: B
```

## Metadata

```yaml
display_name: Futex 等待分布
description: 统计 futex/mutex 锁等待分布与耗时
icon: hourglass_empty
tags:
- lock
- futex
- mutex
- contention
```

## Triggers

```yaml
keywords:
  zh:
  - futex
  - mutex
  - 锁等待
  - 锁竞争
  - 卡锁
  en:
  - futex
  - mutex
  - lock wait
  - contention
patterns:
- .*(futex|mutex|lock).*(wait|contention).*
- .*(锁|互斥).*(等待|竞争).*
```

## Prerequisites

```yaml
required_tables:
- slice
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名(可选)
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

Run [`../sql/futex_wait_distribution/query.sql`](../sql/futex_wait_distribution/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 锁等待分布
columns:
- name: wait_type
  label: 等待类型
  type: string
- name: events
  label: 事件数
  type: number
- name: avg_wait_ms
  label: 平均等待
  type: duration
  format: duration_ms
  unit: ms
- name: p95_wait_ms
  label: P95 等待
  type: duration
  format: duration_ms
  unit: ms
- name: max_wait_ms
  label: 最大等待
  type: duration
  format: duration_ms
  unit: ms
```
