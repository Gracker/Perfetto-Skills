GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/lmk_kill_attribution.skill.yaml
Source SHA-256: 4c299b78e625d37ee05fb8288a3b072ab6151ce29c5f98780a038913d06664ae
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
# LMK 杀进程归因

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: lmk_kill_attribution
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: LMK 杀进程归因
description: Low Memory Killer 杀进程事件列表
icon: delete_forever
tags:
- memory
- lmk
- kill
- oom
- atomic
```

## Prerequisites

```yaml
modules:
- android.memory.lmk
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
  description: 目标进程名 GLOB（可选）
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
```

## Ordered execution

### LMK 事件列表

- ID: `lmk_events`
- Type: `atomic`
- SQL: [`../sql/lmk_kill_attribution/lmk_events.sql`](../sql/lmk_kill_attribution/lmk_events.sql)

```yaml
id: lmk_events
type: atomic
display:
  level: detail
  layer: list
  title: LMK 杀进程事件
  columns:
  - name: ts
    label: 时间
    type: timestamp
  - name: process_name
    label: 被杀进程
    type: string
  - name: pid
    label: PID
    type: number
  - name: oom_score_adj
    label: OOM Score
    type: number
```
