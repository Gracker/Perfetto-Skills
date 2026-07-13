GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/wakeup_frequency_summary.skill.yaml
Source SHA-256: 0284882dd46c3d7d61c0a9efb203c61b2dbff2cc2710d0beb13652f985c9aa5c
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# 唤醒频率摘要

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: wakeup_frequency_summary
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: 唤醒频率摘要
description: 区分设备级 wakeup 与 CPU idle exit churn，按分钟归一化
icon: notifications_active
tags:
- power
- wakeup
- suspend
- cpuidle
- frequency
- atomic
```

## Prerequisites

```yaml
modules:
- android.wakeups
- linux.cpu.idle
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

### 唤醒频率

- ID: `wakeup_frequency`
- Type: `atomic`
- SQL: [`../sql/wakeup_frequency_summary/wakeup_frequency.sql`](../sql/wakeup_frequency_summary/wakeup_frequency.sql)

```yaml
id: wakeup_frequency
type: atomic
display:
  level: summary
  layer: overview
  title: 设备唤醒与 CPU Idle Exit
  columns:
  - name: window_min
    label: 窗口(分钟)
    type: number
    format: compact
  - name: device_wakeup_count
    label: 设备唤醒数
    type: number
    format: compact
  - name: device_wakeups_per_min
    label: 设备唤醒/分钟
    type: number
    format: compact
  - name: cpu_idle_exit_count
    label: CPU idle exit
    type: number
    format: compact
  - name: cpu_idle_exits_per_min
    label: CPU idle exit/分钟
    type: number
    format: compact
  - name: bad_wakeup_count
    label: 低质量唤醒
    type: number
    format: compact
  - name: interpretation
    label: 解释
    type: string
```
## Output and evidence contract

```yaml
format: structured
```
