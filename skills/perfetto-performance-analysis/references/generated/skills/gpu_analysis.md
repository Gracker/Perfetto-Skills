GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/gpu_analysis.skill.yaml
Source SHA-256: c99bd1159e7f337b0d5dd490100f66e9134271d55a7bbf0362ebf64d3a1d9602
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# GPU 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gpu_analysis
version: '3.0'
type: composite
tier: S
```

## Metadata

```yaml
display_name: GPU 分析
description: 分析 GPU 频率分布、内存使用和帧渲染关联，识别 GPU 瓶颈
icon: memory
tags:
- gpu
- rendering
- frequency
- memory
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - GPU
  - 显卡
  - 图形
  - GPU频率
  - GPU内存
  - 显存
  - GPU负载
  - GPU瓶颈
  en:
  - gpu
  - graphics
  - gpu frequency
  - gpu memory
  - gpu load
  - gpu bound
  - mali
  - adreno
patterns:
- .*[Gg][Pp][Uu].*
- .*显卡.*
- .*图形.*性能.*
```

## Prerequisites

```yaml
modules:
- android.gpu.frequency
- android.gpu.memory
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选，不填则分析全局 GPU 状态）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
- name: high_freq_threshold_pct
  type: number
  required: false
  default: 70
  description: GPU 高负载判定阈值（最高频占比百分比）
- name: mid_freq_threshold_pct
  type: number
  required: false
  default: 40
  description: GPU 中负载判定阈值（最高频占比百分比）
- name: low_freq_threshold_pct
  type: number
  required: false
  default: 10
  description: GPU 低负载判定阈值（最高频占比百分比）
- name: freq_drop_ratio
  type: number
  required: false
  default: 0.7
  description: 频率突降检测比例（低于上次频率的该比例视为突降）
- name: freq_drop_count_threshold
  type: number
  required: false
  default: 20
  description: 频率突降次数阈值（超过该值判定为限频）
- name: high_load_min_dur_ns
  type: number
  required: false
  default: 500000000
  description: 高负载时段最小持续时间阈值（纳秒，默认500ms）
```

## Ordered execution

### GPU 数据源检测

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/gpu_analysis/data_check.sql`](../sql/gpu_analysis/data_check.sql)

```yaml
id: data_check
type: atomic
display: false
save_as: data_check
```
### GPU 频率概览

- ID: `gpu_freq_overview`
- Type: `atomic`
- SQL: [`../sql/gpu_analysis/gpu_freq_overview.sql`](../sql/gpu_analysis/gpu_freq_overview.sql)

```yaml
id: gpu_freq_overview
type: atomic
optional: true
synthesize:
  role: overview
  fields:
  - key: weighted_avg_freq_mhz
    label: 加权平均频率
    format: '{{value}} MHz'
  - key: max_freq_time_pct
    label: 最高频占比
    format: '{{value}}%'
  - key: total_time_sec
    label: 总采样时间
    format: '{{value}} s'
  insights:
  - condition: max_freq_time_pct > 70
    template: GPU 在最高频率运行 {{max_freq_time_pct}}%，可能存在 GPU 瓶颈
  - condition: max_freq_time_pct < 10
    template: GPU 大部分时间低频运行，负载较轻
  - condition: freq_change_count > 500
    template: GPU 频率变化 {{freq_change_count}} 次，调频活跃
display:
  level: summary
  layer: overview
  title: GPU 频率概览
  columns:
  - name: gpu_id
    label: GPU ID
    type: number
  - name: weighted_avg_freq_mhz
    label: 加权平均频率
    type: number
    format: compact
  - name: max_freq_mhz
    label: 最高频率
    type: number
    format: compact
  - name: min_freq_mhz
    label: 最低频率
    type: number
    format: compact
  - name: max_freq_time_pct
    label: 最高频占比
    type: percentage
    format: percentage
  - name: freq_levels
    label: 频率档位数
    type: number
  - name: freq_change_count
    label: 变频次数
    type: number
    format: compact
  - name: total_time_sec
    label: 采样时间
    type: number
  - name: rating
    label: 评级
    type: string
save_as: gpu_freq_overview
condition: data_check.data[0]?.has_gpu_data === 1
```
### GPU 内存概览

- ID: `gpu_memory_overview`
- Type: `atomic`
- SQL: [`../sql/gpu_analysis/gpu_memory_overview.sql`](../sql/gpu_analysis/gpu_memory_overview.sql)

```yaml
id: gpu_memory_overview
type: atomic
optional: true
synthesize:
  role: overview
  fields:
  - key: total_max_mb
    label: 全局 GPU 内存峰值
    format: '{{value}} MB'
  - key: process_count
    label: 使用 GPU 内存的进程数
display:
  level: summary
  layer: overview
  title: GPU 内存概览
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: max_gpu_memory_mb
    label: 峰值内存
    type: bytes
    format: compact
  - name: avg_gpu_memory_mb
    label: 平均内存
    type: bytes
    format: compact
  - name: min_gpu_memory_mb
    label: 最小内存
    type: bytes
    format: compact
  - name: memory_change_mb
    label: 内存变化
    type: number
save_as: gpu_memory_overview
condition: data_check.data[0]?.has_gpu_memory === 1
```
### GPU 频率档位分布

- ID: `gpu_freq_distribution`
- Type: `atomic`
- SQL: [`../sql/gpu_analysis/gpu_freq_distribution.sql`](../sql/gpu_analysis/gpu_freq_distribution.sql)

```yaml
id: gpu_freq_distribution
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: GPU 频率档位分布
  columns:
  - name: gpu_id
    label: GPU
    type: number
  - name: gpu_freq_mhz
    label: 频率 (MHz)
    type: number
    format: compact
  - name: total_time_sec
    label: 持续时间
    type: number
  - name: time_pct
    label: 时间占比
    type: percentage
    format: percentage
  - name: is_max_freq
    label: 是否最高频
    type: string
save_as: gpu_freq_distribution
condition: data_check.data[0]?.has_gpu_data === 1
```
### GPU-帧渲染关联

- ID: `gpu_frame_correlation`
- Type: `atomic`
- SQL: [`../sql/gpu_analysis/gpu_frame_correlation.sql`](../sql/gpu_analysis/gpu_frame_correlation.sql)

```yaml
id: gpu_frame_correlation
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: GPU 频率与帧渲染关联
  columns:
  - name: jank_type
    label: 帧类型
    type: string
  - name: frame_count
    label: 帧数
    type: number
    format: compact
  - name: avg_gpu_freq_mhz
    label: 平均 GPU 频率
    type: number
    format: compact
  - name: avg_frame_dur_ms
    label: 平均帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_frame_dur_ms
    label: 最大帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: gpu_freq_range
    label: 频率范围
    type: string
save_as: gpu_frame_correlation
condition: data_check.data[0]?.has_gpu_data === 1 && data_check.data[0]?.has_frame_timeline === 1
```
### GPU 高负载时段

- ID: `gpu_high_load_periods`
- Type: `atomic`
- SQL: [`../sql/gpu_analysis/gpu_high_load_periods.sql`](../sql/gpu_analysis/gpu_high_load_periods.sql)

```yaml
id: gpu_high_load_periods
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: GPU 高负载时段
  columns:
  - name: gpu_id
    label: GPU
    type: number
  - name: start_ts
    label: 开始时间
    type: timestamp
    clickAction: navigate_range
    durationColumn: duration_ns
  - name: high_freq_dur_ms
    label: 高频持续时间
    type: duration
    format: duration_ms
    unit: ms
  - name: segment_count
    label: 段数
    type: number
  - name: duration_ns
    label: 持续时间
    type: duration
    format: duration_ms
    unit: ns
    hidden: true
save_as: gpu_high_load
condition: data_check.data[0]?.has_gpu_data === 1
```
### GPU 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/gpu_analysis/root_cause_classification.sql`](../sql/gpu_analysis/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
optional: true
synthesize:
  role: conclusion
  fields:
  - key: gpu_category
    label: GPU 状态
  - key: confidence
    label: 置信度
    format: '{{value}}%'
  insights:
  - template: GPU 诊断：{{gpu_category}} - {{root_cause_summary}}
display:
  level: summary
  layer: overview
  title: GPU 分析结论
  columns:
  - name: gpu_category
    label: GPU 状态
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
condition: data_check.data[0]?.has_gpu_data === 1
```
### GPU 数据不可用

- ID: `fallback_no_gpu_data`
- Type: `atomic`
- SQL: [`../sql/gpu_analysis/fallback_no_gpu_data.sql`](../sql/gpu_analysis/fallback_no_gpu_data.sql)

```yaml
id: fallback_no_gpu_data
type: atomic
condition: data_check.data[0]?.has_gpu_data === 0
display:
  level: summary
  layer: overview
  title: GPU 分析 - 数据缺失
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
  category: $conclusion.gpu_category
  confidence: $conclusion.confidence
  summary: $conclusion.root_cause_summary
  evidence: $conclusion.evidence
  suggestion: $conclusion.suggestion
```
