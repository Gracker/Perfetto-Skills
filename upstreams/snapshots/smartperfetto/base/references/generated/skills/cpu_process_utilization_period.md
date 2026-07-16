GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_process_utilization_period.skill.yaml
Source SHA-256: a37173b25f5c40b5fdbe2f46e13e980b8eca451f7e52275826547e3480585ea2
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 进程 CPU 利用率

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_process_utilization_period
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: 进程 CPU 利用率
description: 按进程聚合的 CPU 利用率周期采样
icon: leaderboard
tags:
- cpu
- process
- utilization
- atomic
```

## Prerequisites

```yaml
modules:
- linux.cpu.utilization.process
```

## Ordered execution

### 进程 CPU 利用率

- ID: `process_util`
- Type: `atomic`
- SQL: [`../sql/cpu_process_utilization_period/process_util.sql`](../sql/cpu_process_utilization_period/process_util.sql)

```yaml
id: process_util
type: atomic
display:
  level: detail
  layer: list
  title: Top CPU 占用进程
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: utilization
    label: 利用率
    type: number
    format: compact
```
