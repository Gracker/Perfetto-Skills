GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/thermal_throttling.skill.yaml
Source SHA-256: 5fad39740c373b463c8080622927249e67de2e731ea1cf79253d443663541c7e
Source commit: 459063305709d69ae0a322371bba3f506c41c62c
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
    label: 频率变化核心占比
    type: percentage
    format: percentage
  - name: frequency_trend_risk
    label: 频率变化信号
    type: string
  - name: thermal_risk
    label: 热原因证据
    type: string
  - name: prediction
    label: 预测
    type: string
save_as: thermal_prediction
condition: enable_expert_probes !== false && data_check.data[0]?.has_freq_data === 1 && analysis_window.data?.[0]?.window_start_ts
  != null && analysis_window.data?.[0]?.window_end_ts != null
optional: true
```
### 直接限频证据

- ID: `direct_limit_evidence`
- Type: `atomic`
- SQL: [`../sql/thermal_throttling/direct_limit_evidence.sql`](../sql/thermal_throttling/direct_limit_evidence.sql)

```yaml
id: direct_limit_evidence
type: atomic
optional: true
condition: data_check.data?.[0]?.has_limit_data === 1
process_scope:
  role: global_context
sql_fragments:
- fragments/observed_data_bounds.sql
- fragments/system_sched_spans.sql
- fragments/system_cpu_freq_limit_spans.sql
- fragments/system_cpu_freq_limit_episodes.sql
- fragments/thermal_cooling_spans.sql
- fragments/thermal_signal_signatures.sql
- fragments/system_cpu_freq_limit_episode_verdicts.sql
display:
  level: summary
  layer: overview
  title: 直接限频证据（限频区段 x 散热设备）
  columns:
  - name: episode_count
    label: 限频区段数
    type: number
  - name: policy_count
    label: 涉及 policy 数
    type: number
  - name: deepest_depth_pct
    label: 最大限频深度
    type: percentage
  - name: longest_episode_ns
    label: 最长区段
    type: duration
    unit: ns
  - name: cooling_confirmed_episodes
    label: 与散热设备同期的区段
    type: number
  - name: onset_unknown_episodes
    label: 起点不可观测的区段
    type: number
  - name: has_cdev_data
    label: 有内核散热设备数据
    type: boolean
  - name: thermal_throttling_evidence
    label: 热节流证据
    type: string
  - name: next_step
    label: 下一步
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 窗口内没有超过阈值的限频区段。
save_as: direct_limit_evidence
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
    template: 传感器 {{sensor_name}} 峰值 {{max_temp_c}}C，需核对传感器位置和热阈值
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
  - name: sample_quality
    label: 样本质量
    type: string
  - name: unit_basis
    label: 单位依据
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
sql_fragments:
- fragments/thermal_sample_quality.sql
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
    label: 观测频率跨度
  insights:
  - condition: throttle_ratio > 50
    template: CPU{{cpu_id}} 频率下降超过最大频率 50%，仅说明 DVFS 频率变化，不能确定热节流
  - condition: throttle_ratio > 30
    template: CPU{{cpu_id}} 频率下降超过最大频率 30%，需结合负载和直接限频证据判断原因
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
    label: 观测频率跨度(%)
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
sql_fragments:
- fragments/thermal_sample_quality.sql
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
  title: CPU 频率骤降事件（需核对负载）
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
  - condition: status === 'high_temperature_with_low_frequency'
    template: 在 {{second}}s 检测到高温伴随低频，不能据此确定热节流
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
sql_fragments:
- fragments/thermal_sample_quality.sql
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
sql_fragments:
- fragments/thermal_sample_quality.sql
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
    label: 已核验热限频CPU数
  insights:
  - condition: classification === 'DATA_SUSPECT'
    template: 温度数据需复核，峰值 {{peak_temp_c}}C 仅来自通过质量筛选的传感器
  - condition: classification === 'HIGH_TEMP_OBSERVED'
    template: 观测到高温 {{peak_temp_c}}C，热节流原因未核验
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
    label: 已核验热限频CPU数
    type: number
  - name: severe_drop_count
    label: 严重降频次数
    type: number
    format: compact
  - name: thermal_throttling_evidence
    label: 热节流证据
    type: string
  - name: limit_episode_count
    label: 限频区段数
    type: number
  - name: next_step
    label: 下一步
    type: string
  - name: description
    label: 描述
    type: string
sql_fragments:
- fragments/thermal_sample_quality.sql
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
- direct_limit_evidence
- root_cause
rules:
- condition: root_cause.data[0]?.classification === 'THERMAL_LIMIT_CONFIRMED'
  severity: warning
  diagnosis: 已核验热限频：${direct_limit_evidence.data[0].cooling_confirmed_episodes} 段限频区段与内核散热设备的非零档位同时存在（最大深度 ${direct_limit_evidence.data[0].deepest_depth_pct}%）
  confidence: high
  suggestions:
  - 用 cpu_frequency_limit_attribution 查看谁触发了限频、限频前的负载归因与异常线程
  - 核对该散热设备治理的 cpufreq policy 与触发它的热区阈值；cdev_update 事件本身不声明作用对象
- condition: root_cause.data[0]?.thermal_throttling_evidence === 'limit_observed_cause_unverified'
  severity: info
  diagnosis: 观测到 ${direct_limit_evidence.data[0].episode_count} 段限频区段，但没有同期的内核散热设备活动；限频原因未核验
  confidence: medium
  suggestions:
  - 用 cpu_frequency_limit_attribution 判断是用户态温控守护进程、非热策略限频，还是采集缺少 thermal/cdev_update
- condition: root_cause.data[0]?.classification === 'DATA_SUSPECT'
  severity: warning
  diagnosis: 温度数据可疑或传感器不可直接比较；峰值仅来自通过质量筛选的轨道，不能确定热节流
  confidence: low
  suggestions:
  - 检查各轨道 sample_quality、unit_basis 和传感器位置，勿将皮肤温度视为 CPU 结温
- condition: root_cause.data[0]?.classification === 'THERMAL_DATA_UNAVAILABLE'
  severity: info
  diagnosis: 没有足够可靠的温度数据，热状态不可判定
  confidence: low
- condition: root_cause.data[0]?.classification === 'HIGH_TEMP_OBSERVED'
  severity: warning
  diagnosis: 观测到高温 ${root_cause.data[0].peak_temp_c}C；需要持续时间和直接限频证据才能判断热节流
  confidence: medium
- condition: root_cause.data[0]?.classification === 'FREQ_INSTABILITY'
  severity: info
  diagnosis: 观测到 ${root_cause.data[0].severe_drop_count} 次频率下降，负载或空闲 DVFS 均可解释，热原因未核验
  confidence: medium
- condition: root_cause.data[0]?.classification === 'THERMAL_NORMAL'
  severity: info
  diagnosis: 有效传感器未见高温；不代表所有 CPU 结温均可观测
  confidence: medium
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
- direct_limit_evidence
- thermal_overview
- cpu_freq_overview
- root_cause_classification
```
