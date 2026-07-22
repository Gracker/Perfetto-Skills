GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/system_load_in_range.skill.yaml
Source SHA-256: 34013d7fab4cc44f7b9247884e5eedbc9c1d4c6d9a60097fb27a1348815a88bb
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# 系统负载分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: system_load_in_range
version: '1.0'
type: atomic
category: system
tier: B
```

## Metadata

```yaml
display_name: 系统负载分析
description: 分析系统整体 CPU 利用率和进程活跃度
icon: analytics
tags:
- system
- load
- cpu
- atomic
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
```

## Query

Run [`../sql/system_load_in_range/query.sql`](../sql/system_load_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 系统负载
columns:
- name: metric
  label: 指标
  type: string
- name: value
  label: 值
  type: string
```
