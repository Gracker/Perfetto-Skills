GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
Source SHA-256: 883c9e637f8166269939f7f817af9ef900c89e2215ca90cb3c0ad0d45443daad
Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba
# SurfaceFlinger 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: surfaceflinger_analysis
version: '3.0'
type: composite
tier: S
```

## Metadata

```yaml
display_name: SurfaceFlinger 分析
description: 分析 SurfaceFlinger 帧合成性能，包括 GPU/HWC 合成比例、慢合成检测和 Fence 等待
icon: layers
tags:
- surfaceflinger
- composition
- gpu
- vsync
- fence
- display
```

## Triggers

```yaml
keywords:
  zh:
  - SurfaceFlinger
  - SF
  - 合成
  - GPU合成
  - HWC合成
  - VSYNC
  - 显示合成
  - fence
  - 帧合成
  en:
  - surfaceflinger
  - sf
  - composition
  - gpu composition
  - hwc
  - vsync
  - display
  - fence
patterns:
- .*[Ss]urface[Ff]linger.*
- .*合成.*
- .*VSYNC.*同步.*
- .*GPU.*合成.*
```

## Prerequisites

```yaml
modules:
- android.frames.timeline
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选，用于关联应用与 SF 交互）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
- name: slow_composition_multiplier
  type: number
  required: false
  default: 1.5
  description: 慢合成判定倍数（超过 VSync 周期的该倍数视为慢合成）
- name: composition_rating_poor_ms
  type: number
  required: false
  default: 12
  description: 合成评级-较差阈值（平均合成耗时 ms）
- name: composition_rating_fair_ms
  type: number
  required: false
  default: 8
  description: 合成评级-一般阈值（平均合成耗时 ms）
- name: composition_rating_good_ms
  type: number
  required: false
  default: 4
  description: 合成评级-良好阈值（平均合成耗时 ms）
- name: long_fence_threshold_ms
  type: number
  required: false
  default: 10
  description: 长 Fence 等待阈值（ms）
- name: fence_critical_ms
  type: number
  required: false
  default: 16
  description: Fence 严重程度-critical 阈值（ms）
- name: fence_warning_ms
  type: number
  required: false
  default: 8
  description: Fence 严重程度-warning 阈值（ms）
- name: slow_pct_threshold
  type: number
  required: false
  default: 10
  description: 慢合成占比阈值（百分比，超过则判定为合成延迟）
- name: gpu_comp_ratio_threshold
  type: number
  required: false
  default: 0.5
  description: GPU 合成比例阈值（超过该比例判定为 GPU 合成负载高）
```

## Ordered execution

### SurfaceFlinger 数据检测

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_analysis/data_check.sql`](../sql/surfaceflinger_analysis/data_check.sql)

```yaml
id: data_check
type: atomic
display: false
save_as: data_check
```
### VSync 配置

- ID: `vsync_config`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_analysis/vsync_config.sql`](../sql/surfaceflinger_analysis/vsync_config.sql)

```yaml
id: vsync_config
type: atomic
display:
  level: summary
  layer: overview
  title: 显示配置
  columns:
  - name: refresh_rate_hz
    label: 刷新率
    type: number
    format: compact
  - name: vsync_period_ms
    label: VSync 周期
    type: duration
    format: duration_ms
    unit: ms
  - name: vsync_source
    label: 来源
    type: string
save_as: vsync_env
condition: data_check.data[0]?.has_sf_process === 1
```
### 合成概览

- ID: `composition_overview`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_analysis/composition_overview.sql`](../sql/surfaceflinger_analysis/composition_overview.sql)

```yaml
id: composition_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: total_compositions
    label: 总合成数
  - key: avg_composition_ms
    label: 平均合成耗时
    format: '{{value}} ms'
  - key: gpu_composition_pct
    label: GPU 合成比例
    format: '{{value}}%'
  insights:
  - condition: gpu_composition_pct > 50
    template: GPU 合成比例 {{gpu_composition_pct}}%，较高，可能影响功耗
  - condition: slow_composition_count > 5
    template: 检测到 {{slow_composition_count}} 次慢合成 (超过 1.5x VSync 周期)
  - condition: avg_composition_ms > 8
    template: 平均合成耗时 {{avg_composition_ms}}ms，偏高
display:
  level: summary
  layer: overview
  title: SurfaceFlinger 合成概览
  columns:
  - name: total_compositions
    label: 总合成数
    type: number
    format: compact
  - name: avg_composition_dur
    label: 平均合成耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: max_composition_dur
    label: 最大合成耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: p95_composition_dur
    label: P95 合成耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: slow_composition_count
    label: 慢合成次数
    type: number
    format: compact
  - name: rating
    label: 评级
    type: string
save_as: composition_overview
condition: data_check.data[0]?.has_composition_data === 1
```
### GPU/HWC 合成统计

- ID: `gpu_hwc_stats`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_analysis/gpu_hwc_stats.sql`](../sql/surfaceflinger_analysis/gpu_hwc_stats.sql)

```yaml
id: gpu_hwc_stats
type: atomic
optional: true
display:
  level: summary
  layer: overview
  title: GPU vs HWC 合成
  columns:
  - name: composition_type
    label: 合成方式
    type: string
  - name: frame_count
    label: 帧数
    type: number
    format: compact
  - name: pct
    label: 占比
    type: percentage
    format: percentage
  - name: avg_dur
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: max_dur
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ns
save_as: gpu_hwc_stats
condition: data_check.data[0]?.has_composition_data === 1
```
### 慢合成列表

- ID: `slow_compositions`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_analysis/slow_compositions.sql`](../sql/surfaceflinger_analysis/slow_compositions.sql)

```yaml
id: slow_compositions
type: atomic
display:
  level: detail
  layer: list
  title: 慢合成事件 (>1.5x VSync)
  columns:
  - name: start_ts
    label: 开始时间
    type: timestamp
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 合成耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: event_name
    label: 事件
    type: string
  - name: vsync_missed
    label: 错过 VSync 数
    type: number
  - name: severity
    label: 严重程度
    type: enum
save_as: slow_compositions
condition: data_check.data[0]?.has_composition_data === 1
```
### Fence 等待分析

- ID: `fence_analysis`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_analysis/fence_analysis.sql`](../sql/surfaceflinger_analysis/fence_analysis.sql)

```yaml
id: fence_analysis
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: Fence 等待事件
  columns:
  - name: start_ts
    label: 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: dur
    label: 等待时间
    type: duration
    format: duration_ms
    unit: ns
  - name: fence_type
    label: Fence 类型
    type: string
  - name: severity
    label: 严重程度
    type: enum
save_as: fence_analysis
condition: data_check.data[0]?.has_sf_process === 1
```
### 合成阶段分布

- ID: `composition_phases`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_analysis/composition_phases.sql`](../sql/surfaceflinger_analysis/composition_phases.sql)

```yaml
id: composition_phases
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 合成阶段耗时
  columns:
  - name: phase
    label: 合成阶段
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: avg_dur
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: max_dur
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: time_pct
    label: 时间占比
    type: percentage
    format: percentage
save_as: composition_phases
condition: data_check.data[0]?.has_composition_data === 1
```
### Layer 统计

- ID: `layer_stats`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_analysis/layer_stats.sql`](../sql/surfaceflinger_analysis/layer_stats.sql)

```yaml
id: layer_stats
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 活跃 Layer 统计
  columns:
  - name: layer_name
    label: Layer
    type: string
  - name: frame_count
    label: 帧数
    type: number
    format: compact
  - name: total_dur
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: avg_dur
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ns
save_as: layer_stats
condition: data_check.data[0]?.has_sf_process === 1
```
### SF 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_analysis/root_cause_classification.sql`](../sql/surfaceflinger_analysis/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
synthesize:
  role: conclusion
  fields:
  - key: sf_category
    label: SF 状态
  - key: confidence
    label: 置信度
    format: '{{value}}%'
  insights:
  - template: SurfaceFlinger 诊断：{{sf_category}} - {{root_cause_summary}}
display:
  level: summary
  layer: overview
  title: SurfaceFlinger 分析结论
  columns:
  - name: sf_category
    label: 问题分类
    type: enum
  - name: confidence
    label: 置信度
    type: percentage
    format: percentage
  - name: root_cause_summary
    label: 根因总结
    type: string
  - name: evidence
    label: 关键证据
    type: string
  - name: suggestion
    label: 优化建议
    type: string
save_as: conclusion
condition: data_check.data[0]?.has_composition_data === 1
```
### SF 数据不可用

- ID: `fallback_no_sf_data`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_analysis/fallback_no_sf_data.sql`](../sql/surfaceflinger_analysis/fallback_no_sf_data.sql)

```yaml
id: fallback_no_sf_data
type: atomic
condition: data_check.data[0]?.has_sf_process === 0
display:
  level: summary
  layer: overview
  title: SurfaceFlinger 分析 - 数据缺失
  columns:
  - name: status
    label: 状态
    type: string
  - name: missing_data
    label: 缺失数据
    type: string
  - name: suggestion
    label: 建议
    type: string
save_as: fallback_info
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- overview
- list
conclusion:
  category: $conclusion.sf_category
  confidence: $conclusion.confidence
  summary: $conclusion.root_cause_summary
  evidence: $conclusion.evidence
  suggestion: $conclusion.suggestion
```
