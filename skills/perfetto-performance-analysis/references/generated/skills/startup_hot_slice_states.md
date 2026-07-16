GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_hot_slice_states.skill.yaml
Source SHA-256: 7b53b185503a7dbaaf1ddc0527728dc763324f140dc4b673f65e56d18926eba6
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 热点 Slice 线程状态分布

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_hot_slice_states
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 热点 Slice 线程状态分布
description: 分析启动区间内 Top N 热点 Slice 各自的线程状态分布（Running/S/D/R）及 blocked_functions
icon: timeline
tags:
- startup
- main_thread
- state
- slice
- per_slice
- atomic
```

## Prerequisites

```yaml
modules: null
```

## Inputs

```yaml
- name: package
  type: string
  required: true
- name: start_ts
  type: timestamp
  required: true
- name: end_ts
  type: timestamp
  required: true
- name: top_n
  type: number
  required: false
```

## Query

Run [`../sql/startup_hot_slice_states/query.sql`](../sql/startup_hot_slice_states/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 热点 Slice 线程状态分布
columns:
- name: slice_name
  label: 切片名
  type: string
- name: slice_dur_ms
  label: 切片耗时
  type: duration
  format: duration_ms
  unit: ms
- name: slice_ts
  label: 开始时间
  type: timestamp
- name: state
  label: 线程状态
  type: string
- name: state_dur_ms
  label: 状态耗时
  type: duration
  format: duration_ms
  unit: ms
- name: state_pct
  label: 状态占比
  type: percentage
  format: percentage
- name: io_wait
  label: io_wait
  type: number
  format: compact
- name: evidence_strength
  label: 证据强度
  type: string
- name: blocked_functions
  label: 阻塞函数
  type: string
  format: truncate
```
