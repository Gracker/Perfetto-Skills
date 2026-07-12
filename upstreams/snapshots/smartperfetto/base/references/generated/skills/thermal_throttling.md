GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/thermal_throttling.skill.yaml
Source SHA-256: da05d8739326315402aed126434265da76f5216ccd8cefbbfa0ee780bbfe9f6c
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d
# 热节流分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: thermal_throttling
version: '3.0'
type: composite
tier: S
```

## Metadata

```yaml
display_name: 热节流分析
description: 分析系统温度、热节流对 CPU 频率和性能的影响
icon: thermometer
tags:
- thermal
- throttling
- temperature
- cpu
- frequency
- system
```

## Triggers

```yaml
keywords:
  zh:
  - 温度
  - 热节流
  - 降频
  - 发热
  - 过热
  - 散热
  - 温控
  en:
  - thermal
  - throttling
  - temperature
  - frequency
  - overheat
  - cooling
  - heat
patterns:
- .*温度.*
- .*[热發].*节流.*
- .*[Tt]hermal.*
- .*[Tt]hrottl.*
- .*降频.*
- .*过热.*
```

## Prerequisites

```yaml
required_tables:
- counter
modules: []
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
- name: enable_expert_probes
  type: boolean
  required: false
  default: true
  description: 是否启用专家探针（热预测/GPU DVFS）
- name: thermal_predictor_high_drop_pct
  type: number
  required: false
  default: 30
  description: 热预测高风险的平均降频阈值（%）
- name: thermal_predictor_medium_drop_pct
  type: number
  required: false
  default: 15
  description: 热预测中风险的平均降频阈值（%）
- name: thermal_predictor_high_core_ratio_pct
  type: number
  required: false
  default: 50
  description: 热预测高风险的限频核心占比阈值（%）
- name: thermal_predictor_medium_core_ratio_pct
  type: number
  required: false
  default: 25
  description: 热预测中风险的限频核心占比阈值（%）
- name: thermal_predictor_core_drop_threshold_pct
  type: number
  required: false
  default: 30
  description: 判定单核心疑似限频的降频阈值（%）
- name: gpu_transition_threshold_pct
  type: number
  required: false
  default: 12
  description: GPU 升降频判定阈值（%）
- name: gpu_downshift_warning_pct
  type: number
  required: false
  default: 25
  description: GPU 降频占比告警阈值（%）
```

## Ordered execution

### 温度数据检测

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/data_check.sql`](../sql/thermal_throttling/data_check.sql)

```yaml
id: data_check
type: atomic
display: false
save_as: data_check
```
### 热分析窗口

- ID: `expert_analysis_window`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/expert_analysis_window.sql`](../sql/thermal_throttling/expert_analysis_window.sql)

```yaml
id: expert_analysis_window
type: atomic
display: false
save_as: analysis_window
condition: enable_expert_probes !== false && (data_check.data[0]?.has_thermal_data === 1 || data_check.data[0]?.has_freq_data
  === 1 || data_check.data[0]?.has_gpu_freq_data === 1)
optional: true
```
### 热风险预测

- ID: `thermal_predictor_probe`
- Type: `skill`

```yaml
id: thermal_predictor_probe
type: skill
skill: thermal_predictor
params:
  start_ts: ${analysis_window.data?.[0]?.window_start_ts ?? start_ts ?? null}
  end_ts: ${analysis_window.data?.[0]?.window_end_ts ?? end_ts ?? null}
  high_drop_threshold_pct: ${thermal_predictor_high_drop_pct|30}
  medium_drop_threshold_pct: ${thermal_predictor_medium_drop_pct|15}
  high_core_ratio_threshold_pct: ${thermal_predictor_high_core_ratio_pct|50}
  medium_core_ratio_threshold_pct: ${thermal_predictor_medium_core_ratio_pct|25}
  core_drop_threshold_pct: ${thermal_predictor_core_drop_threshold_pct|30}
display:
  level: summary
  layer: overview
  title: 热风险预测（专家探针）
  columns:
  - name: avg_start_freq_mhz
    label: 区间初段频率
    type: number
  - name: avg_end_freq_mhz
    label: 区间末段频率
    type: number
  - name: avg_drop_pct
    label: 平均降幅
    type: percentage
    format: percentage
  - name: throttled_core_ratio_pct
    label: 疑似限频核心占比
    type: percentage
    format: percentage
  - name: thermal_risk
    label: 热风险
    type: string
  - name: prediction
    label: 预测
    type: string
save_as: thermal_prediction
condition: enable_expert_probes !== false && data_check.data[0]?.has_freq_data === 1 && analysis_window.data?.[0]?.window_start_ts
  != null && analysis_window.data?.[0]?.window_end_ts != null
optional: true
```
### 温度传感器概览

- ID: `thermal_overview`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/thermal_overview.sql`](../sql/thermal_throttling/thermal_overview.sql)

```yaml
id: thermal_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: sensor_name
    label: 传感器
  - key: max_temp_c
    label: 最高温度
    format: '{{value}} C'
  - key: avg_temp_c
    label: 平均温度
    format: '{{value}} C'
  - key: temp_severity
    label: 温度评级
  insights:
  - condition: max_temp_c > 80
    template: 传感器 {{sensor_name}} 峰值 {{max_temp_c}}C，存在严重过热
  - condition: max_temp_c > 60 && max_temp_c <= 80
    template: 传感器 {{sensor_name}} 峰值 {{max_temp_c}}C，温度偏高
  - condition: temp_range_c > 20
    template: 传感器 {{sensor_name}} 温度波动 {{temp_range_c}}C，波动较大
display:
  level: summary
  layer: overview
  title: 温度传感器概览
  columns:
  - name: sensor_name
    label: 传感器
    type: string
  - name: sample_count
    label: 采样数
    type: number
    format: compact
  - name: min_temp_c
    label: 最低温度
    type: number
    format: compact
  - name: max_temp_c
    label: 最高温度
    type: number
    format: compact
  - name: avg_temp_c
    label: 平均温度
    type: number
    format: compact
  - name: temp_range_c
    label: 温度波动
    type: number
    format: compact
  - name: temp_severity
    label: 评级
    type: string
save_as: thermal_overview
optional: true
condition: data_check.data[0]?.has_thermal_data === 1
```
### CPU 频率概览

- ID: `cpu_freq_overview`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/cpu_freq_overview.sql`](../sql/thermal_throttling/cpu_freq_overview.sql)

```yaml
id: cpu_freq_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: cpu_id
    label: CPU 核心
  - key: min_freq_mhz
    label: 最低频率
    format: '{{value}} MHz'
  - key: max_freq_mhz
    label: 最高频率
    format: '{{value}} MHz'
  - key: throttle_ratio
    label: 节流比例
  insights:
  - condition: throttle_ratio > 50
    template: CPU{{cpu_id}} 频率下降超过最大频率 50%，存在显著节流
  - condition: throttle_ratio > 30
    template: CPU{{cpu_id}} 频率下降超过最大频率 30%，存在中度节流
display:
  level: summary
  layer: overview
  title: CPU 频率与节流状态
  columns:
  - name: cpu_id
    label: CPU
    type: number
  - name: min_freq_mhz
    label: 最低频率
    type: number
    format: compact
  - name: max_freq_mhz
    label: 最高频率
    type: number
    format: compact
  - name: avg_freq_mhz
    label: 平均频率
    type: number
    format: compact
  - name: sample_count
    label: 采样数
    type: number
    format: compact
  - name: throttle_ratio
    label: 节流比例(%)
    type: percentage
    format: percentage
  - name: throttling_status
    label: 状态
    type: string
save_as: cpu_freq_overview
optional: true
condition: data_check.data[0]?.has_freq_data === 1
```
### GPU DVFS 探针

- ID: `gpu_power_probe`
- Type: `skill`

```yaml
id: gpu_power_probe
type: skill
skill: gpu_power_state_analysis
params:
  start_ts: ${analysis_window.data?.[0]?.window_start_ts ?? start_ts ?? null}
  end_ts: ${analysis_window.data?.[0]?.window_end_ts ?? end_ts ?? null}
  transition_threshold_pct: ${gpu_transition_threshold_pct|12}
display:
  level: detail
  layer: list
  title: GPU 功耗状态（专家探针）
  columns:
  - name: gpu_id
    label: GPU
    type: number
  - name: samples
    label: 采样数
    type: number
  - name: avg_freq_mhz
    label: 平均频率(MHz)
    type: number
  - name: min_freq_mhz
    label: 最低频率(MHz)
    type: number
  - name: max_freq_mhz
    label: 最高频率(MHz)
    type: number
  - name: downshift_count
    label: 降频次数
    type: number
  - name: downshift_ratio_pct
    label: 降频占比
    type: percentage
    format: percentage
save_as: gpu_power_probe
condition: enable_expert_probes !== false && data_check.data[0]?.has_gpu_freq_data === 1 && analysis_window.data?.[0]?.window_start_ts
  != null && analysis_window.data?.[0]?.window_end_ts != null
optional: true
```
### 温度变化时间线

- ID: `thermal_timeline`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/thermal_timeline.sql`](../sql/thermal_throttling/thermal_timeline.sql)

```yaml
id: thermal_timeline
type: atomic
display:
  level: detail
  layer: list
  title: 温度变化趋势
  columns:
  - name: ts
    label: 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: sensor_name
    label: 传感器
    type: string
  - name: temp_c
    label: 温度(C)
    type: number
    format: compact
  - name: delta_c
    label: 变化(C)
    type: number
    format: compact
  - name: severity
    label: 状态
    type: string
save_as: thermal_timeline
optional: true
condition: data_check.data[0]?.has_thermal_data === 1
```
### 频率骤降事件

- ID: `frequency_drop_events`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/frequency_drop_events.sql`](../sql/thermal_throttling/frequency_drop_events.sql)

```yaml
id: frequency_drop_events
type: atomic
synthesize:
  role: list
  groupBy:
  - field: cpu_id
    title: 按 CPU 核心分布
  fields:
  - key: cpu_id
    label: CPU
  - key: drop_pct
    label: 降频幅度
    format: '{{value}}%'
  - key: prev_freq_mhz
    label: 降频前
    format: '{{value}} MHz'
display:
  level: detail
  layer: list
  title: CPU 频率骤降事件（可能因热节流）
  columns:
  - name: ts
    label: 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: cpu_id
    label: CPU
    type: number
  - name: prev_freq_mhz
    label: 降频前
    type: number
    format: compact
  - name: new_freq_mhz
    label: 降频后
    type: number
    format: compact
  - name: drop_pct
    label: 降幅(%)
    type: percentage
    format: percentage
  - name: severity
    label: 严重程度
    type: string
save_as: frequency_drops
optional: true
condition: data_check.data[0]?.has_freq_data === 1
```
### 温度-频率相关性

- ID: `thermal_freq_correlation`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/thermal_freq_correlation.sql`](../sql/thermal_throttling/thermal_freq_correlation.sql)

```yaml
id: thermal_freq_correlation
type: atomic
synthesize:
  role: list
  fields:
  - key: second
    label: 时间(秒)
  - key: max_temp_c
    label: 最高温度
    format: '{{value}} C'
  - key: avg_freq_mhz
    label: 平均频率
    format: '{{value}} MHz'
  - key: status
    label: 状态
  insights:
  - condition: status === 'thermal_throttled'
    template: 在 {{second}}s 检测到高温伴随低频，存在热节流
display:
  level: detail
  layer: list
  title: 温度与 CPU 频率关联（按秒聚合）
  columns:
  - name: second
    label: 时间(s)
    type: number
  - name: max_temp_c
    label: 最高温度(C)
    type: number
    format: compact
  - name: avg_freq_mhz
    label: 平均频率(MHz)
    type: number
    format: compact
  - name: freq_ratio_pct
    label: 频率利用率(%)
    type: percentage
    format: percentage
  - name: status
    label: 状态
    type: string
save_as: thermal_freq_correlation
optional: true
condition: data_check.data[0]?.has_thermal_data === 1 && data_check.data[0]?.has_freq_data === 1
```
### 高温时段

- ID: `high_temp_periods`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/high_temp_periods.sql`](../sql/thermal_throttling/high_temp_periods.sql)

```yaml
id: high_temp_periods
type: atomic
display:
  level: detail
  layer: list
  title: 高温持续时段
  columns:
  - name: sensor_name
    label: 传感器
    type: string
  - name: start_ts
    label: 开始
    type: timestamp
    clickAction: navigate_timeline
  - name: end_ts
    label: 结束
    type: timestamp
    clickAction: navigate_timeline
  - name: duration_sec
    label: 持续(秒)
    type: number
    format: compact
  - name: peak_temp_c
    label: 峰值温度(C)
    type: number
    format: compact
  - name: sample_count
    label: 采样数
    type: number
    format: compact
save_as: high_temp_periods
optional: true
condition: data_check.data[0]?.has_thermal_data === 1
```
### 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/root_cause_classification.sql`](../sql/thermal_throttling/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
synthesize:
  role: conclusion
  fields:
  - key: classification
    label: 分类
  - key: peak_temp_c
    label: 峰值温度
    format: '{{value}} C'
  - key: throttled_cpu_count
    label: 受影响CPU数
  insights:
  - condition: classification === 'THERMAL_THROTTLING'
    template: 热节流严重：峰值 {{peak_temp_c}}C，{{throttled_cpu_count}} 核受影响
  - condition: classification === 'SUSTAINED_HIGH_TEMP'
    template: 持续高温 {{peak_temp_c}}C，存在热节流风险
display:
  level: summary
  layer: overview
  title: 热节流根因分类
  columns:
  - name: classification
    label: 分类
    type: string
  - name: peak_temp_c
    label: 峰值温度(C)
    type: number
    format: compact
  - name: throttled_cpu_count
    label: 受影响CPU数
    type: number
  - name: severe_drop_count
    label: 严重降频次数
    type: number
    format: compact
  - name: description
    label: 描述
    type: string
save_as: root_cause
condition: data_check.data[0]?.has_thermal_data === 1 || data_check.data[0]?.has_freq_data === 1
```
### 热节流诊断

- ID: `thermal_diagnosis`
- Type: `diagnostic`

```yaml
id: thermal_diagnosis
type: diagnostic
synthesize:
  role: conclusion
  fields:
  - key: diagnosis
    label: 诊断结论
  - key: severity
    label: 严重程度
  - key: confidence
    label: 置信度
  insights:
  - template: 热节流诊断：{{diagnosis}}
display:
  level: key
  layer: overview
  title: 问题诊断
inputs:
- thermal_overview
- cpu_freq_overview
- thermal_prediction
- gpu_power_probe
- frequency_drops
- high_temp_periods
- root_cause
rules:
- condition: root_cause.data[0]?.classification === 'THERMAL_THROTTLING'
  severity: critical
  diagnosis: 检测到热节流：峰值 ${root_cause.data[0].peak_temp_c}C，${root_cause.data[0].throttled_cpu_count} 核受影响
  confidence: high
  suggestions:
  - 减少后台 CPU 密集任务
  - 优化计算密集操作，添加冷却间隔
  - 检查设备散热条件
- condition: root_cause.data[0]?.classification === 'SUSTAINED_HIGH_TEMP'
  severity: warning
  diagnosis: 持续高温 ${root_cause.data[0].peak_temp_c}C，存在热节流风险
  confidence: high
  suggestions:
  - 降低持续 CPU 负载
  - 避免长时间高强度计算
  - 监控温度变化趋势
- condition: (thermal_prediction?.data?.[0]?.thermal_risk || '') === 'high'
  severity: critical
  diagnosis: 热风险预测为高：频率平均降幅 ${thermal_prediction.data[0].avg_drop_pct}%
  confidence: high
  suggestions:
  - 立即降低持续计算密度，增加任务分批与冷却间隔
  - 优先优化后台并发，避免长时间满载
  - 结合温度传感器与 FPS 继续观测 1-3 分钟趋势
- condition: (gpu_power_probe?.data?.[0]?.downshift_ratio_pct || 0) >= (gpu_downshift_warning_pct || 25)
  severity: warning
  diagnosis: GPU 降频占比 ${gpu_power_probe.data[0].downshift_ratio_pct}% ，存在图形侧热压或功耗抖动
  confidence: medium
  suggestions:
  - 降低高峰渲染负载，减少过度绘制和昂贵 shader
  - 平滑 GPU 突发任务，避免频繁升降频震荡
- condition: root_cause.data[0]?.classification === 'FREQ_INSTABILITY'
  severity: warning
  diagnosis: CPU 频率不稳定 (${root_cause.data[0].severe_drop_count} 次骤降)，可能受温度影响
  confidence: medium
  suggestions:
  - 检查散热条件
  - 优化任务调度避免突发负载
- condition: root_cause.data[0]?.classification === 'THERMAL_NORMAL'
  severity: info
  diagnosis: 温度正常，无明显热节流
  confidence: high
  suggestions:
  - 当前热状态良好
```
### 无温度数据

- ID: `no_data_fallback`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/no_data_fallback.sql`](../sql/thermal_throttling/no_data_fallback.sql)

```yaml
id: no_data_fallback
type: atomic
display:
  level: summary
  layer: overview
  title: 温度数据不可用
  columns:
  - name: message
    label: 说明
    type: string
save_as: no_data_fallback
condition: data_check.data[0]?.has_thermal_data !== 1 && data_check.data[0]?.has_freq_data !== 1 && data_check.data[0]?.has_gpu_freq_data
  !== 1
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- thermal_overview
- cpu_freq_overview
- root_cause_classification
```
