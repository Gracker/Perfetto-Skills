GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/present_fence_timing.skill.yaml
Source SHA-256: 13da4eb5934736e0b60cb39f01f7e306b873de90f9f210090bb4dcd3a0a62c7d
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# Present Fence 时序分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: present_fence_timing
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: Present Fence 时序分析
description: 分析 Present Fence 的时序，检测实际显示延迟
icon: fence
tags:
- present
- fence
- timing
- display
pipeline_aware: true
pipeline_aware_note: 'Tunneled Video 下 App 看不到 present，要走 HAL trace tag；XR 下端到端延迟用 motion-to-photon。

  未来按 pipeline_id 切换 present 时序解析（HWC vs HAL sideband vs XR compositor）。

  '
```

## Triggers

```yaml
keywords:
  zh:
  - present fence
  - release fence
  - fence 等待
  - 显示 fence
  - HWC
  en:
  - present fence
  - release fence
  - fence wait
  - hwc fence
patterns:
- .*(present|release).*fence.*
- .*fence.*(等待|wait).*
```

## Prerequisites

```yaml
required_tables:
- slice
modules:
- android.frames.timeline
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

### Present Fence 统计

- ID: `present_fence_stats`
- Type: `atomic`
- SQL: [`../sql/present_fence_timing/present_fence_stats.sql`](../sql/present_fence_timing/present_fence_stats.sql)

```yaml
id: present_fence_stats
type: atomic
display:
  level: summary
  format: table
  columns:
  - name: total_fences
    label: 总 Fence 数
    type: number
  - name: avg_wait_ms
    label: 平均等待
    type: duration
    format: duration_ms
  - name: max_wait_ms
    label: 最大等待
    type: duration
    format: duration_ms
  - name: slow_fences_vsync
    label: 超帧预算
    type: number
  - name: slow_rate_pct
    label: 超时率
    type: percentage
  - name: vsync_period_ms
    label: VSync 周期
    type: duration
    format: duration_ms
  - name: gpu_status
    label: GPU 状态
    type: string
save_as: fence_stats
optional: true
```
