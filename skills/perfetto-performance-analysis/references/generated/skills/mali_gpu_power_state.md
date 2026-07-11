GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/mali_gpu_power_state.skill.yaml
Source SHA-256: 2846582cac7aa964a047a495575cb21b1517b7d63bf7d6bc261baf43847ed6db
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# Mali GPU 电源状态

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: mali_gpu_power_state
version: '1.0'
type: atomic
category: gpu
tier: B
```

## Metadata

```yaml
display_name: Mali GPU 电源状态
description: Mali GPU 电源状态变化序列
icon: memory
tags:
- gpu
- mali
- power
- state
- atomic
```

## Prerequisites

```yaml
modules:
- android.gpu.mali_power_state
```

## Ordered execution

### Mali 状态时间线

- ID: `mali_state`
- Type: `atomic`
- SQL: [`../sql/mali_gpu_power_state/mali_state.sql`](../sql/mali_gpu_power_state/mali_state.sql)

```yaml
id: mali_state
type: atomic
display:
  level: detail
  layer: list
  title: Mali GPU 电源状态
  columns:
  - name: ts
    label: 时间
    type: timestamp
  - name: dur_ms
    label: 时长(ms)
    type: duration
    format: duration_ms
  - name: power_state
    label: 状态
    type: string
```
