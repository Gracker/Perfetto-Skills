GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_slow_reasons.skill.yaml
Source SHA-256: 9280e9531cabb0d33f372861fc25136e7e273f9b5c0a3e1cb38d346213d38a58
Source commit: 68b113e0355716255af357e8396cd71c71e11d97
# 启动慢原因（官方分类）

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_slow_reasons
version: '3.0'
type: composite
category: app_lifecycle
tier: S
```

## Metadata

```yaml
display_name: 启动慢原因（官方分类）
description: 检测 20+ 种已知的启动慢原因，交叉验证自有分析
icon: checklist
tags:
- startup
- slow_reasons
- official
- google
- diagnostics
```

## Prerequisites

```yaml
modules:
- android.startup.startups
- android.startup.time_to_display
```

## Ordered execution

### 启动事件汇总

- ID: `startup_overview`
- Type: `atomic`
- SQL: [`../sql/startup_slow_reasons/startup_overview.sql`](../sql/startup_slow_reasons/startup_overview.sql)

```yaml
id: startup_overview
type: atomic
display:
  level: key
  layer: list
  title: 启动事件及 TTID/TTFD 耗时
  columns:
  - name: startup_id
    label: 启动 ID
    type: number
    format: compact
  - name: package
    label: 包名
    type: string
  - name: startup_type
    label: 启动类型
    type: string
  - name: dur_ms
    label: 启动耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: ttid_ms
    label: TTID(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: ttfd_ms
    label: TTFD(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: ts
    label: 启动开始时间(ns)
    type: timestamp
    hidden: true
  - name: dur
    label: 启动耗时(ns)
    type: duration
    hidden: true
  - name: upid
    label: 进程UPID
    type: number
    hidden: true
save_as: startup_overview
optional: true
```
### 慢启动原因检测

- ID: `slow_reason_checks`
- Type: `atomic`
- SQL: [`../sql/startup_slow_reasons/slow_reason_checks.sql`](../sql/startup_slow_reasons/slow_reason_checks.sql)

```yaml
id: slow_reason_checks
type: atomic
condition: startup_overview.data.length > 0
display:
  level: key
  layer: list
  title: 检测到的慢启动原因
  columns:
  - name: reason_id
    label: 原因编号
    type: string
  - name: reason
    label: 慢启动原因
    type: string
  - name: severity
    label: 严重程度
    type: string
  - name: evidence
    label: 证据
    type: string
  - name: suggestion
    label: 建议
    type: string
save_as: slow_reasons
optional: true
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- slow_reasons
```
