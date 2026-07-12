GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/fence_wait_decomposition.skill.yaml
Source SHA-256: 182d5e6b03a0ccfbd53f5da992628513e87e9afe773539e0fc312d54148568af
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# Fence 等待分解（acquire/present/release）

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: fence_wait_decomposition
version: '1.0'
type: composite
category: diagnostics
tier: A
```

## Metadata

```yaml
display_name: Fence 等待分解（acquire/present/release）
description: 按 3 种 fence 分类计时，归因 jank 到具体 fence 类型；内置 5ms/16ms 阈值是启发式，报告高刷新率场景时需结合 vsync_config/present_fence_timing
icon: schedule
tags:
- fence
- acquire
- present
- release
- surfaceflinger
- gpu
- s01
s_article_ref: S01
```

## Prerequisites

```yaml
required_tables:
- slice
- thread
- process
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 分析结束时间戳(ns)
- name: package
  type: string
  required: false
  description: 应用包名（可选，用于过滤 dequeueBuffer 等待）
```

## Ordered execution

### Acquire Fence 等待（SF latch）

- ID: `acquire_fence_wait`
- Type: `atomic`
- SQL: [`../sql/fence_wait_decomposition/acquire_fence_wait.sql`](../sql/fence_wait_decomposition/acquire_fence_wait.sql)

```yaml
id: acquire_fence_wait
type: atomic
display:
  level: summary
  layer: overview
  title: Acquire Fence 等待概览
  columns:
  - name: total_acquire_buffer
    label: acquireBuffer 总次数
    type: number
  - name: avg_acquire_ms
    label: 平均 acquireBuffer 耗时
    type: duration
    format: duration_ms
  - name: p95_acquire_ms
    label: P95 acquireBuffer 耗时
    type: duration
    format: duration_ms
  - name: max_acquire_ms
    label: 最大 acquireBuffer 耗时
    type: duration
    format: duration_ms
save_as: acquire_fence_wait
```
### Present Fence 时机（HWC presentDisplay）

- ID: `present_fence_timing`
- Type: `atomic`
- SQL: [`../sql/fence_wait_decomposition/present_fence_timing.sql`](../sql/fence_wait_decomposition/present_fence_timing.sql)

```yaml
id: present_fence_timing
type: atomic
display:
  level: summary
  layer: overview
  title: Present Fence 概览
  columns:
  - name: total_present_display
    label: presentDisplay 总次数
    type: number
  - name: avg_present_ms
    label: 平均 presentDisplay 耗时
    type: duration
    format: duration_ms
  - name: p95_present_ms
    label: P95 presentDisplay 耗时
    type: duration
    format: duration_ms
  - name: late_present_count
    label: presentDisplay > 固定16ms启发次数
    type: number
save_as: present_fence_timing
```
### Release Fence 影响（App dequeueBuffer 等待）

- ID: `release_fence_impact`
- Type: `atomic`
- SQL: [`../sql/fence_wait_decomposition/release_fence_impact.sql`](../sql/fence_wait_decomposition/release_fence_impact.sql)

```yaml
id: release_fence_impact
type: atomic
display:
  level: summary
  layer: overview
  title: Release Fence 等待概览
  columns:
  - name: total_dequeue_buffer
    label: dequeueBuffer 总次数
    type: number
  - name: avg_dequeue_ms
    label: 平均 dequeueBuffer 耗时
    type: duration
    format: duration_ms
  - name: p95_dequeue_ms
    label: P95 dequeueBuffer 耗时
    type: duration
    format: duration_ms
  - name: blocked_dequeue_count
    label: dequeueBuffer > 5ms 次数（疑似卡 release fence）
    type: number
save_as: release_fence_impact
```
### Fence 三分归因提示

- ID: `fence_attribution_hint`
- Type: `atomic`
- SQL: [`../sql/fence_wait_decomposition/fence_attribution_hint.sql`](../sql/fence_wait_decomposition/fence_attribution_hint.sql)

```yaml
id: fence_attribution_hint
type: atomic
display:
  level: summary
  layer: overview
  title: Fence 三分归因建议
  columns:
  - name: dominant_fence_issue
    label: 主导 Fence 问题
    type: string
  - name: hint
    label: 诊断建议
    type: string
save_as: fence_attribution_hint
```
## Output and evidence contract

```yaml
fields:
- name: acquire_fence_wait
  label: Acquire fence 等待（SF latch 阶段）
- name: present_fence_timing
  label: Present fence 时机（HWC presentDisplay）
- name: release_fence_impact
  label: Release fence 影响（App dequeueBuffer 等待）
- name: fence_attribution_hint
  label: Fence 三分综合归因建议
```
