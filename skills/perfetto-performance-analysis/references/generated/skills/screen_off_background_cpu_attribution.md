GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/screen_off_background_cpu_attribution.skill.yaml
Source SHA-256: 30326a1331437f9fc5fba924c3b897a885ae7407962cab6d49007e66e9ffbb62
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# 熄屏后台 CPU 归因

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: screen_off_background_cpu_attribution
version: '1.0'
type: atomic
category: power
tier: A
```

## Metadata

```yaml
display_name: 熄屏后台 CPU 归因
description: 在 screen-off / doze 窗口内按进程/线程聚合 CPU runtime，定位后台偷跑
icon: screen_lock_portrait
tags:
- power
- screen_off
- background_cpu
- sched
- attribution
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - 熄屏 CPU
  - 后台 CPU
  - screen-off CPU
  - 待机耗电
  - 偷跑
  en:
  - screen-off CPU
  - background CPU
  - standby drain
  - background drain
patterns:
- .*(熄屏|待机|screen-off).*(CPU|后台).*
- .*background.*CPU.*
```

## Prerequisites

```yaml
required_tables:
- sched
- thread
- process
modules:
- android.screen_state
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标包名或进程名前缀（可选）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: top_n
  type: number
  required: false
  default: 30
  description: 返回前 N 个后台 CPU 进程/线程
```

## Ordered execution

### 熄屏后台 CPU

- ID: `screen_off_cpu`
- Type: `atomic`
- SQL: [`../sql/screen_off_background_cpu_attribution/screen_off_cpu.sql`](../sql/screen_off_background_cpu_attribution/screen_off_cpu.sql)

```yaml
id: screen_off_cpu
type: atomic
display:
  level: summary
  layer: list
  title: 熄屏/Doze 窗口后台 CPU
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: screen_off_time_sec
    label: 熄屏窗口(秒)
    type: number
    format: compact
  - name: runtime_ms
    label: CPU runtime(ms)
    type: duration
    format: duration_ms
  - name: cpu_util_pct
    label: CPU 占用(%)
    type: percentage
  - name: evidence_status
    label: 证据状态
    type: string
```
## Output and evidence contract

```yaml
format: structured
```
