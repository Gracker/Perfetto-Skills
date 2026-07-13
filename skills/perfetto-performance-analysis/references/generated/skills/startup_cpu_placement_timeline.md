GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_cpu_placement_timeline.skill.yaml
Source SHA-256: 2697e8f8785a219d21dc73847d18ecba03b50728a78f3eab6721dfebee25ff4b
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# 启动摆核时序分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_cpu_placement_timeline
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 启动摆核时序分析
description: 按时间桶分析主线程的核类型变化，检测启动初期被困小核
icon: timeline
tags:
- startup
- cpu
- placement
- timeline
- migration
- atomic
```

## Prerequisites

```yaml
modules: null
```

## Inputs

```yaml
- name: package
  type: string
  required: true
- name: start_ts
  type: timestamp
  required: true
- name: end_ts
  type: timestamp
  required: true
- name: bucket_ms
  type: number
  required: false
```

## Query

Run [`../sql/startup_cpu_placement_timeline/query.sql`](../sql/startup_cpu_placement_timeline/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 主线程摆核时序
columns:
- name: bucket_idx
  label: 时间桶
  type: number
- name: bucket_offset_ms
  label: 偏移(ms)
  type: number
- name: big_core_ms
  label: 大核运行(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: little_core_ms
  label: 小核运行(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: big_core_pct
  label: 大核占比
  type: percentage
  format: percentage
- name: used_cpus
  label: 使用 CPU
  type: string
- name: core_types
  label: 核类型
  type: string
```
