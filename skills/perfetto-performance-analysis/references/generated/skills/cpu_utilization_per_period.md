GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_utilization_per_period.skill.yaml
Source SHA-256: 9920c14a1dfb568ab235f8ad07dc05900335274cf3a7715383808227764b30a7
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
# 系统 CPU 利用率

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_utilization_per_period
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: 系统 CPU 利用率
description: 整机 CPU 利用率按周期采样
icon: speed
tags:
- cpu
- utilization
- system
- atomic
```

## Prerequisites

```yaml
modules:
- linux.cpu.utilization.system
```

## Ordered execution

### 系统 CPU 利用率

- ID: `system_util`
- Type: `atomic`
- SQL: [`../sql/cpu_utilization_per_period/system_util.sql`](../sql/cpu_utilization_per_period/system_util.sql)

```yaml
id: system_util
type: atomic
display:
  level: detail
  layer: list
  title: 周期 CPU 利用率
  columns:
  - name: ts
    label: 时间
    type: timestamp
  - name: dur_ms
    label: 周期(ms)
    type: duration
    format: duration_ms
  - name: utilization
    label: 利用率
    type: number
    format: compact
```
