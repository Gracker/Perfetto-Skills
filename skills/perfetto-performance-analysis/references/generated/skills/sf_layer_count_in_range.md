GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/sf_layer_count_in_range.skill.yaml
Source SHA-256: 32c86a668275bbbc02ac545c67d1fef7366d86414bac478468751d7dde71027a
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# SF 图层数统计

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: sf_layer_count_in_range
version: '1.0'
type: composite
category: diagnostics
tier: B
```

## Metadata

```yaml
display_name: SF 图层数统计
description: 统计时间范围内 SurfaceFlinger 活跃图层数量，辅助 SF 合成性能诊断
icon: layers
tags:
- surfaceflinger
- layer
- composition
- diagnostics
pipeline_aware: true
pipeline_aware_note: 'Layer 数量是辅助证据轴之一，不是独立类型分类法。expected_layer_count 按 pipeline 不同：

  标准/TextureView=1, SurfaceView/Mixed≥2, HC overlay=N, WebView Functor=0。

  未来按 pipeline_id 标注期望 layer 数 + 偏离判定。

  '
```

## Prerequisites

```yaml
required_tables:
- actual_frame_timeline_slice
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
- name: process_name
  type: string
  required: false
  description: 聚焦进程名（可选，用于区分前台 App Layer 和其他 Layer）
```

## Ordered execution

### 活跃图层统计

- ID: `layer_summary`
- Type: `atomic`
- SQL: [`../sql/sf_layer_count_in_range/layer_summary.sql`](../sql/sf_layer_count_in_range/layer_summary.sql)

```yaml
id: layer_summary
type: atomic
display:
  level: summary
  layer: overview
  title: SF 图层概览
  columns:
  - name: total_layers
    label: 总图层数
    type: number
  - name: app_layers
    label: App 图层数
    type: number
  - name: system_layers
    label: 系统图层数
    type: number
  - name: avg_concurrent_layers
    label: 平均并发图层数
    type: number
  - name: max_concurrent_layers
    label: 最大并发图层数
    type: number
save_as: sf_layer_summary
```
### 图层列表

- ID: `layer_list`
- Type: `atomic`
- SQL: [`../sql/sf_layer_count_in_range/layer_list.sql`](../sql/sf_layer_count_in_range/layer_list.sql)

```yaml
id: layer_list
type: atomic
display:
  level: detail
  layer: list
  title: 活跃图层列表
  columns:
  - name: layer_name
    label: 图层名
    type: string
  - name: layer_type
    label: 类型
    type: string
  - name: frame_count
    label: 帧数
    type: number
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
  - name: jank_count
    label: 掉帧数
    type: number
save_as: sf_layer_list
```
