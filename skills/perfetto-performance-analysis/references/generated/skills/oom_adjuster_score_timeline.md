GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/oom_adjuster_score_timeline.skill.yaml
Source SHA-256: c955d048f6d17e0c4063656ab3f1b2468226e04ce68b76ef596f479b158bb973
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# OOM Score 时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: oom_adjuster_score_timeline
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: OOM Score 时间线
description: 进程 oom_score_adj 变化区间
icon: low_priority
tags:
- memory
- oom
- lmk
- priority
- atomic
```

## Prerequisites

```yaml
modules:
- android.oom_adjuster
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

### OOM Score 区间

- ID: `oom_intervals`
- Type: `atomic`
- SQL: [`../sql/oom_adjuster_score_timeline/oom_intervals.sql`](../sql/oom_adjuster_score_timeline/oom_intervals.sql)

```yaml
id: oom_intervals
type: atomic
display:
  level: detail
  layer: list
  title: 进程 OOM Score 变化
  columns:
  - name: ts
    label: 起始时间
    type: timestamp
  - name: dur_sec
    label: 时长(秒)
    type: duration
    format: compact
  - name: process_name
    label: 进程
    type: string
  - name: oom_score_adj
    label: OOM Score
    type: number
  - name: bucket_name
    label: 进程优先级
    type: string
```
