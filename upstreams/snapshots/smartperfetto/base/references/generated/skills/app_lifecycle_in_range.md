GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/app_lifecycle_in_range.skill.yaml
Source SHA-256: 46a213c077050ea2c95c604806c96bb5c113ed136f248dffca36700952df16f2
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# 应用生命周期事件 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: app_lifecycle_in_range
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 应用生命周期事件 (区间)
description: 追踪区间内 Activity/Fragment 生命周期事件（onCreate/onResume 等）
icon: sync_alt
tags:
- lifecycle
- activity
- fragment
- atomic
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
  description: 目标进程名（支持 GLOB）
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

Run [`../sql/app_lifecycle_in_range/query.sql`](../sql/app_lifecycle_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: list
title: 应用生命周期事件
columns:
- name: ts
  label: 时间
  type: timestamp
  unit: ns
  clickAction: navigate_range
  durationColumn: dur_ns
- name: slice_name
  label: Slice 名称
  type: string
- name: lifecycle_phase
  label: 生命周期阶段
  type: string
- name: component_type
  label: 组件类型
  type: string
- name: process_name
  label: 进程
  type: string
- name: dur_ms
  label: 耗时
  type: duration
  format: duration_ms
- name: dur_ns
  label: 耗时(ns)
  type: duration
  format: duration_ms
  unit: ns
  hidden: true
- name: status
  label: 状态
  type: string
```
