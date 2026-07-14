GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_job_scheduler_events.skill.yaml
Source SHA-256: 5afb016bd89088c8c317111e7909bd82a536b14a6e63d3b9b668f4e765304826
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# JobScheduler 事件

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_job_scheduler_events
version: '1.0'
type: atomic
category: background
tier: B
```

## Metadata

```yaml
display_name: JobScheduler 事件
description: JobScheduler 后台任务执行序列
icon: schedule
tags:
- job_scheduler
- background
- lifecycle
- atomic
```

## Prerequisites

```yaml
modules:
- android.job_scheduler
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标包名 GLOB（可选）
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

### Job 事件列表

- ID: `job_events`
- Type: `atomic`
- SQL: [`../sql/android_job_scheduler_events/job_events.sql`](../sql/android_job_scheduler_events/job_events.sql)

```yaml
id: job_events
type: atomic
display:
  level: detail
  layer: list
  title: JobScheduler 任务
  columns:
  - name: ts
    label: 时间
    type: timestamp
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
  - name: job_name
    label: 任务名
    type: string
  - name: package_name
    label: 包名
    type: string
  - name: uid
    label: UID
    type: number
```
