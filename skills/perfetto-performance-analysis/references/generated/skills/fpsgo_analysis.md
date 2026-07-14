GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/fpsgo_analysis.skill.yaml
Source SHA-256: 6ee6815848f62092599d709a15c857835fb298f96733192f8fc113c03acb42c3
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# FPSGO 策略分析 (MTK)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: fpsgo_analysis
version: '1.0'
type: atomic
category: vendor
tier: B
```

## Metadata

```yaml
display_name: FPSGO 策略分析 (MTK)
description: 检测 MTK FPSGO 帧感知调度框架的运行状态（FSTB/FBT/急拉/频率地板）
icon: settings
tags:
- mtk
- fpsgo
- fstb
- fbt
- boost
- vendor
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

Run [`../sql/fpsgo_analysis/query.sql`](../sql/fpsgo_analysis/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: summary
layer: overview
title: FPSGO 策略状态
columns:
- name: category
  label: 策略类别
  type: string
- name: event_name
  label: 事件名
  type: string
- name: count
  label: 次数
  type: number
- name: total_ms
  label: 总时长
  type: duration
  format: duration_ms
```
