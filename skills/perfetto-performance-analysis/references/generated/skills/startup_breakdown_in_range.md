GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_breakdown_in_range.skill.yaml
Source SHA-256: acdca121c21c877922518048f6698fead940d1d8dadf91209910bbcd4be3810b
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# 启动归因分解 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_breakdown_in_range
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 启动归因分解 (区间)
description: 统计启动阶段各归因原因耗时占比
icon: analytics
tags:
- startup
- breakdown
- atomic
```

## Prerequisites

```yaml
modules:
- android.startup.startups
- android.startup.startup_breakdowns
```

## Inputs

```yaml
- name: package
  type: string
  required: false
- name: startup_id
  type: integer
  required: false
- name: startup_type
  type: string
  required: false
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
- name: top_k
  type: integer
  required: false
```

## Query

Run [`../sql/startup_breakdown_in_range/query.sql`](../sql/startup_breakdown_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: overview
title: 启动延迟归因分析
columns:
- name: reason
  label: 延迟原因
  type: string
- name: count
  label: 次数
  type: number
  format: compact
- name: total_dur_ms
  label: 总耗时
  type: duration
  format: duration_ms
- name: avg_dur_ms
  label: 平均耗时
  type: duration
  format: duration_ms
- name: max_dur_ms
  label: 最大耗时
  type: duration
  format: duration_ms
- name: percent
  label: 占比
  type: percentage
  format: percentage
- name: category
  label: 类别
  type: string
```
