GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/vsync_alignment_in_range.skill.yaml
Source SHA-256: 39143e628c5b370c0ea897c41246b2e976efcb4d956045b99e99a0151af04443
Source commit: 67a2eec9888ed577e66284c709f4987a617bd286
# VSync 对齐分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: vsync_alignment_in_range
version: '1.0'
type: atomic
category: display
tier: B
```

## Metadata

```yaml
display_name: VSync 对齐分析
description: 分析帧与 VSync 信号的对齐情况
icon: sync
tags:
- vsync
- display
- timing
- atomic
pipeline_aware: true
pipeline_aware_note: 'Camera/Video/Game(Swappy) 不严格对齐 vsync-app（各自有独立节奏）。

  未来按 pipeline_id 切换"对齐预期"判定（vsync-app 严格 vs Camera HAL 节奏 vs Swappy frame pacing）。

  '
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
  required: true
  description: 帧开始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 帧结束时间戳(ns)
```

## Query

Run [`../sql/vsync_alignment_in_range/query.sql`](../sql/vsync_alignment_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: VSync 对齐
columns:
- name: metric
  label: 指标
  type: string
- name: value
  label: 值
  type: string
```
