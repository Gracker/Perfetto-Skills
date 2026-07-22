GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_idle_analysis.skill.yaml
Source SHA-256: 231e8ce685c178ba67e1e32c7f5fcdb25ba5b5b0b0773af5145ca0572d6b4861
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# CPU Idle C-State 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_idle_analysis
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: CPU Idle C-State 分析
description: 分析 CPU idle 状态分布，检测深度 idle 对唤醒延迟的影响
icon: cpu
tags:
- cpu
- idle
- cstate
- wakeup
- latency
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
- name: cpu_ids
  type: json_array
  required: false
  description: 'Portable binding: pass a JSON array through --param; do not pass a preformatted SQL list.'
  source_type: string
  source_description: CPU ID 列表（逗号分隔，如 '4,5,6,7'）
```

## Query

Run [`../sql/cpu_idle_analysis/query.sql`](../sql/cpu_idle_analysis/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: overview
title: CPU Idle 分析
columns:
- name: cpu
  label: CPU
  type: number
- name: idle_state
  label: Idle 状态
  type: number
- name: entry_count
  label: 进入次数
  type: number
- name: total_idle_ms
  label: 总 Idle 时长
  type: duration
  format: duration_ms
- name: avg_idle_ms
  label: 平均 Idle 时长
  type: duration
  format: duration_ms
- name: max_idle_ms
  label: 最大 Idle 时长
  type: duration
  format: duration_ms
```
