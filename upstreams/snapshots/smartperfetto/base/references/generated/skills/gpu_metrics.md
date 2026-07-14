GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/gpu_metrics.skill.yaml
Source SHA-256: 7ec44d892abb05141d0c58bfb05944911a22d8a6d4252fc95aa9b12c5f4f800a
Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba
# GPU 指标分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gpu_metrics
version: '1.0'
type: atomic
category: hardware
tier: A
```

## Metadata

```yaml
display_name: GPU 指标分析
description: 分析 GPU 频率、利用率和渲染性能
icon: gpu
tags:
- gpu
- frequency
- utilization
- performance
- atomic
```

## Prerequisites

```yaml
optional_tables:
- gpu_counter_track
- slice
- counter
modules:
- android.frames.timeline
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
- name: package
  type: string
  required: false
```

## Ordered execution

### GPU 频率

- ID: `gpu_frequency`
- Type: `atomic`
- SQL: [`../sql/gpu_metrics/gpu_frequency.sql`](../sql/gpu_metrics/gpu_frequency.sql)

```yaml
id: gpu_frequency
type: atomic
display:
  level: summary
  title: GPU 频率
  columns:
  - name: avg_freq_mhz
    label: 平均频率
    type: number
  - name: max_freq_mhz
    label: 最大频率
    type: number
  - name: min_freq_mhz
    label: 最小频率
    type: number
  - name: median_freq_mhz
    label: 中位频率
    type: number
  - name: sample_count
    label: 样本数
    type: number
    format: compact
  - name: freq_counters
    label: 计数器
    type: string
    format: truncate
save_as: gpu_freq
optional: true
```
### GPU 利用率

- ID: `gpu_utilization`
- Type: `atomic`
- SQL: [`../sql/gpu_metrics/gpu_utilization.sql`](../sql/gpu_metrics/gpu_utilization.sql)

```yaml
id: gpu_utilization
type: atomic
display:
  level: summary
  title: GPU 利用率
  columns:
  - name: avg_utilization_pct
    label: 平均利用率
    type: percentage
    format: percentage
  - name: max_utilization_pct
    label: 最大利用率
    type: percentage
    format: percentage
  - name: min_utilization_pct
    label: 最小利用率
    type: percentage
    format: percentage
  - name: p95_utilization_pct
    label: P95利用率
    type: percentage
    format: percentage
  - name: sample_count
    label: 样本数
    type: number
    format: compact
save_as: gpu_util
optional: true
```
### GPU 渲染耗时

- ID: `gpu_render_time`
- Type: `atomic`
- SQL: [`../sql/gpu_metrics/gpu_render_time.sql`](../sql/gpu_metrics/gpu_render_time.sql)

```yaml
id: gpu_render_time
type: atomic
display:
  level: detail
  title: GPU 渲染耗时
  columns:
  - name: gpu_operation
    label: 操作
    type: string
  - name: occurrence_count
    label: 次数
    type: number
    format: compact
  - name: total_time_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_time_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_time_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: p95_time_ms
    label: P95耗时
    type: duration
    format: duration_ms
    unit: ms
save_as: gpu_render_time
optional: true
```
### GPU Fence 等待

- ID: `gpu_fence_waits`
- Type: `atomic`
- SQL: [`../sql/gpu_metrics/gpu_fence_waits.sql`](../sql/gpu_metrics/gpu_fence_waits.sql)

```yaml
id: gpu_fence_waits
type: atomic
display:
  level: detail
  title: GPU Fence 等待
  columns:
  - name: total_fence_waits
    label: 等待次数
    type: number
    format: compact
  - name: total_wait_ms
    label: 总等待
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_wait_ms
    label: 平均等待
    type: duration
    format: duration_ms
    unit: ms
  - name: max_wait_ms
    label: 最大等待
    type: duration
    format: duration_ms
    unit: ms
  - name: p95_wait_ms
    label: P95等待
    type: duration
    format: duration_ms
    unit: ms
  - name: vsync_period_ms
    label: VSync周期
    type: duration
    format: duration_ms
    unit: ms
  - name: waits_over_vsync
    label: 超周期次数
    type: number
    format: compact
  - name: gpu_status
    label: GPU状态
    type: string
save_as: gpu_fence
optional: true
```
### GPU 汇总

- ID: `gpu_summary`
- Type: `atomic`
- SQL: [`../sql/gpu_metrics/gpu_summary.sql`](../sql/gpu_metrics/gpu_summary.sql)

```yaml
id: gpu_summary
type: atomic
display:
  level: summary
  title: GPU 状态汇总
  columns:
  - name: freq_data
    label: 频率数据
    type: string
  - name: util_data
    label: 利用率数据
    type: string
  - name: slice_data
    label: 切片数据
    type: string
  - name: total_metrics
    label: 可用指标数
    type: number
save_as: gpu_summary
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: gpu_freq
  description: GPU 频率统计
- name: gpu_util
  description: GPU 利用率统计
- name: gpu_render_time
  description: GPU 渲染耗时
- name: gpu_fence
  description: GPU Fence 等待统计
- name: gpu_summary
  description: GPU 数据可用性汇总
```
