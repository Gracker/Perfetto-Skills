GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_process_utilization_period.skill.yaml
Source SHA-256: 7ab91a94b9e4a6be4e1b8224e9e1b993140280825cff454d6124a73e98b00ec8
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
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
