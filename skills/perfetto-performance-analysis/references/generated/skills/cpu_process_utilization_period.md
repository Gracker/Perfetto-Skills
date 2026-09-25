GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_process_utilization_period.skill.yaml
Source SHA-256: 78a91e3d2a1f6e5640cfab917092a5c5463f08cb7051b7ab9d63f4f4e8258524
Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5
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

## Inputs

```yaml
- name: process_name
  type: string
  required: false
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
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
