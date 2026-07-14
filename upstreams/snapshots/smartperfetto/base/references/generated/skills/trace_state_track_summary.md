GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/trace_state_track_summary.skill.yaml
Source SHA-256: 2cdb80f8ba21476ade7c51c601baad2f3af62cfa24ec319d2506c30c043c5699
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# Trace State Track Summary

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: trace_state_track_summary
version: '1.0'
type: atomic
category: system
tier: B
```

## Metadata

```yaml
display_name: Trace State Track Summary
description: Summarize Perfetto v57 state table intervals by track, category, and symbolic value
icon: view_timeline
tags:
- state
- track
- timeline
- upstream_v57
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - state track
  - 状态轨
  - 状态表
  - 符号状态
  en:
  - state track
  - state table
  - symbolic state
  - track state
patterns:
- .*state.*track.*
- .*状态.*轨.*
```

## Prerequisites

```yaml
modules:
- viz.summary.track_event
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: Start timestamp in ns
- name: end_ts
  type: timestamp
  required: false
  description: End timestamp in ns
- name: track_name
  type: string
  required: false
  description: Optional track name substring
- name: category
  type: string
  required: false
  description: Optional state category substring
- name: max_rows
  type: integer
  required: false
  default: 80
  description: Maximum rows to return
```

## Query

Run [`../sql/trace_state_track_summary/query.sql`](../sql/trace_state_track_summary/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
fields:
- name: total_dur_ms
  description: Total duration for each symbolic state value on a track
- name: share_pct
  description: Share of all filtered state duration represented by this grouped row
```

## Display metadata

```yaml
level: summary
layer: list
title: State Track Summary
columns:
- name: track_name
  label: Track
  type: string
- name: category
  label: Category
  type: string
- name: state_value
  label: State
  type: string
- name: event_count
  label: Count
  type: number
- name: total_dur_ms
  label: Total(ms)
  type: number
- name: avg_dur_ms
  label: Avg(ms)
  type: number
- name: max_dur_ms
  label: Max(ms)
  type: number
- name: first_ts
  label: First
  type: timestamp
  unit: ns
- name: last_ts
  label: Last
  type: timestamp
  unit: ns
- name: share_pct
  label: Share
  type: percentage
  format: percentage
```
