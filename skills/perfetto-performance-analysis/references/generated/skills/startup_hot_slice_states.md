GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_hot_slice_states.skill.yaml
Source SHA-256: 6f1cb08c42ead7e7aa287894f77a423902cbe8e0cbe67bea6e8b9699f7fc777c
Source commit: bc007586871a720aed82537913617c64fb95a459
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
description: 按窗口内裁剪时长采样启动区间 Top N 主线程 Slice，并分析每个原生 Slice 的线程状态分布及覆盖缺口
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
- name: sample_rank
  label: 样本排名
  type: number
  format: compact
- name: slice_id
  label: Slice ID
  type: number
  format: compact
- name: upid
  label: UPID
  type: number
  format: compact
- name: utid
  label: UTID
  type: number
  format: compact
- name: pid
  label: PID
  type: number
  format: compact
- name: tid
  label: TID
  type: number
  format: compact
- name: process_name
  label: 进程
  type: string
- name: thread_name
  label: 线程
  type: string
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
  unit: ns
- name: slice_end_ts
  label: 结束时间
  type: timestamp
  unit: ns
- name: raw_slice_ts
  label: 原始开始时间
  type: timestamp
  unit: ns
- name: raw_slice_end_ts
  label: 原始结束时间
  type: timestamp
  unit: ns
- name: raw_slice_dur_ms
  label: 原始耗时
  type: duration
  format: duration_ms
  unit: ms
- name: left_censored
  label: 左侧裁剪
  type: number
  format: compact
- name: right_censored
  label: 右侧裁剪
  type: number
  format: compact
- name: is_unfinished
  label: 未结束
  type: number
  format: compact
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
- name: state_coverage_ms
  label: 状态覆盖
  type: duration
  format: duration_ms
  unit: ms
- name: state_coverage_pct
  label: 状态覆盖率
  type: percentage
  format: percentage
- name: uncovered_ms
  label: 未覆盖时长
  type: duration
  format: duration_ms
  unit: ms
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
- name: sample_limit
  label: 样本上限
  type: number
  format: compact
- name: sampling_scope
  label: 采样口径
  type: string
- name: eligible_slice_count
  label: 候选 Slice 数
  type: number
  format: compact
- name: selected_slice_count
  label: 入选 Slice 数
  type: number
  format: compact
```
