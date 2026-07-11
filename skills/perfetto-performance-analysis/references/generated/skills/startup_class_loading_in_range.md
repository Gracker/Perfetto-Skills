GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_class_loading_in_range.skill.yaml
Source SHA-256: 67a9f4747f25293a9194b9302ad554294fbc8efdd5397b50c7f74664a0899a34
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 启动类加载分析 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_class_loading_in_range
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 启动类加载分析 (区间)
description: 统计启动阶段类加载切片耗时
icon: dataset
tags:
- startup
- class_loading
- dex
- atomic
```

## Prerequisites

```yaml
modules:
- android.startup.startups
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

Run [`../sql/startup_class_loading_in_range/query.sql`](../sql/startup_class_loading_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: list
title: 启动期间类加载
columns:
- name: slice_name
  label: 类名
  type: string
- name: thread_name
  label: 线程
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
- name: percent_of_startup
  label: 启动占比
  type: percentage
  format: percentage
```
