GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/app_process_starts_summary.skill.yaml
Source SHA-256: b6c52e29a1056ff902bdfb67ff8c9e187457aea4660d8ac95764a4b4c8907df4
Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f
# 应用进程启动汇总

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: app_process_starts_summary
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 应用进程启动汇总
description: 系统层面所有应用进程 fork 事件（含后台/service 进程）
icon: playlist_add
tags:
- process
- fork
- lifecycle
- atomic
```

## Prerequisites

```yaml
modules:
- android.app_process_starts
```

## Inputs

```yaml
- name: package
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

### 进程启动事件

- ID: `process_starts`
- Type: `atomic`
- SQL: [`../sql/app_process_starts_summary/process_starts.sql`](../sql/app_process_starts_summary/process_starts.sql)

```yaml
id: process_starts
type: atomic
display:
  level: detail
  layer: list
  title: 应用进程启动事件
  columns:
  - name: process_name
    label: 进程名
    type: string
  - name: process_start_ts
    label: 启动时间
    type: timestamp
  - name: total_dur_ms
    label: 启动耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: reason
    label: 启动原因
    type: string
```
