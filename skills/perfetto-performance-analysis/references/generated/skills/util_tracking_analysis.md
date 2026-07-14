GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/util_tracking_analysis.skill.yaml
Source SHA-256: 05f535c2fcad4c73b0f5d2dbe56e94502556a6b720d7c85bf8dcd54146c732b2
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# Util 建模分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: util_tracking_analysis
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: Util 建模分析
description: 分析 EAS util tracking 信号（eas_util/sugov_util），检测 WALT/PELT 建模滞后
icon: cpu
tags:
- eas
- util
- walt
- pelt
- scheduling
- atomic
```

## Inputs

```yaml
- name: package
  type: string
  required: true
  description: 目标进程名
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

Run [`../sql/util_tracking_analysis/query.sql`](../sql/util_tracking_analysis/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: Util 建模分析
columns:
- name: offset_ms
  label: 偏移(ms)
  type: number
- name: cpu
  label: CPU
  type: number
- name: running_ms
  label: 运行时间
  type: duration
  format: duration_ms
- name: freq_mhz
  label: 频率(MHz)
  type: number
```
