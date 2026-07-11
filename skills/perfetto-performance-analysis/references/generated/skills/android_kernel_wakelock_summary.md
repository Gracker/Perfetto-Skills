GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_kernel_wakelock_summary.skill.yaml
Source SHA-256: 460ab6fbd3f45ed72d7f8492cd2f73ce2d0205a7d72326f470b52d22b6c54ff0
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# Kernel Wakelock 汇总

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_kernel_wakelock_summary
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: Kernel Wakelock 汇总
description: kernel wakelock 持有时长（阻止 suspend 的源头）
icon: lock_open
tags:
- wakelock
- kernel
- suspend
- power
- atomic
```

## Prerequisites

```yaml
modules:
- android.kernel_wakelocks
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

## Ordered execution

### Wakelock 汇总

- ID: `wakelock_summary`
- Type: `atomic`
- SQL: [`../sql/android_kernel_wakelock_summary/wakelock_summary.sql`](../sql/android_kernel_wakelock_summary/wakelock_summary.sql)

```yaml
id: wakelock_summary
type: atomic
display:
  level: detail
  layer: list
  title: Kernel Wakelock 持有时长
  columns:
  - name: name
    label: Wakelock
    type: string
  - name: total_held_sec
    label: 总持有(秒)
    type: duration
    format: compact
  - name: count
    label: 次数
    type: number
    format: compact
  - name: held_ratio_pct
    label: 唤醒期占比(%)
    type: percentage
  - name: observed_window_hours
    label: 观测窗口(小时)
    type: number
    format: compact
  - name: evidence_scope
    label: 证据范围
    type: string
  - name: vitals_hint
    label: Vitals 参考
    type: string
```
