GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/hardware/thermal_module.skill.yaml
Source SHA-256: fc8a23df5565689fd067df4b8f2fb32e90a8ddc8f1ca0a7df410f8108cedf708
Source commit: 68b113e0355716255af357e8396cd71c71e11d97
# 热管理分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: thermal_module
version: '1.0'
type: composite
category: hardware
```

## Metadata

```yaml
display_name: 热管理分析
description: 分析温度传感器、热节流和散热策略
tags:
- hardware
- thermal
- temperature
- throttling
- cooling
```

## Prerequisites

```yaml
required_tables:
- counter
- counter_track
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: Analysis start timestamp
- name: end_ts
  type: timestamp
  required: false
  description: Analysis end timestamp
```

## Module contract

```yaml
layer: hardware
component: Thermal
subsystems:
- temperature_sensors
- thermal_throttling
- cooling_device
- thermal_zone
relatedModules:
- hardware_cpu
- hardware_gpu
- kernel_scheduler
```

## Dialogue guidance

```yaml
capabilities:
- id: thermal_overview
  questionTemplate: What is the thermal state during the trace?
  requiredParams: []
  description: Get overall thermal status
- id: thermal_throttling_analysis
  questionTemplate: Is there thermal throttling affecting performance?
  requiredParams: []
  optionalParams:
  - start_ts
  - end_ts
  description: Detect and analyze thermal throttling
- id: temperature_timeline
  questionTemplate: How did temperature change over time?
  requiredParams: []
  description: Track temperature changes throughout trace
- id: thermal_correlation
  questionTemplate: Is temperature affecting CPU/GPU performance?
  requiredParams: []
  description: Correlate thermal state with performance metrics
findingsSchema:
- id: thermal_throttling_detected
  severity: critical
  titleTemplate: 'Thermal throttling detected: {throttle_level}'
  descriptionTemplate: CPU/GPU throttled due to temperature ({temp}°C exceeds {threshold}°C)
  evidenceFields:
  - throttle_level
  - temp
  - threshold
  - affected_component
- id: high_temperature
  severity: warning
  titleTemplate: 'High temperature: {zone_name} at {temp}°C'
  descriptionTemplate: Thermal zone {zone_name} reached {temp}°C, approaching threshold
  evidenceFields:
  - zone_name
  - temp
  - threshold
- id: temperature_spike
  severity: warning
  titleTemplate: 'Temperature spike: +{delta}°C in {duration_sec}s'
  descriptionTemplate: Rapid temperature increase detected
  evidenceFields:
  - delta
  - duration_sec
  - peak_temp
  - zone_name
- id: sustained_high_temp
  severity: critical
  titleTemplate: 'Sustained high temperature: {avg_temp}°C for {duration_sec}s'
  descriptionTemplate: Temperature remained high for extended period
  evidenceFields:
  - avg_temp
  - duration_sec
  - zone_name
suggestionsSchema:
- id: check_cpu_frequency
  condition: throttling_detected == true
  targetModule: cpu_module
  questionTemplate: How did thermal throttling affect CPU frequency?
  paramsMapping: {}
  priority: 1
- id: check_gpu_during_thermal
  condition: gpu_temp_high == true
  targetModule: gpu_module
  questionTemplate: How did thermal state affect GPU performance?
  paramsMapping: {}
  priority: 1
```

## Ordered execution

### 温度概览

- ID: `temperature_overview`
- Type: `atomic`
- SQL: [`../sql/thermal_module/temperature_overview.sql`](../sql/thermal_module/temperature_overview.sql)

```yaml
id: temperature_overview
type: atomic
display:
  level: key
  layer: overview
  title: 温度传感器概览
save_as: temp_overview
synthesize:
  role: overview
  fields:
  - key: sensor_name
    label: 传感器
  - key: avg_temp
    label: 平均温度
    format: '{{value}}°C'
  - key: max_temp
    label: 最高温度
    format: '{{value}}°C'
  - key: status
    label: 状态
on_empty: 未找到温度数据，请确保 trace 包含 thermal/temperature 计数器
```
### 温度时间线

- ID: `temperature_timeline`
- Type: `atomic`
- SQL: [`../sql/thermal_module/temperature_timeline.sql`](../sql/thermal_module/temperature_timeline.sql)

```yaml
id: temperature_timeline
type: atomic
display:
  level: detail
  layer: list
  title: 温度时间线
save_as: temp_timeline
```
### 高温时段

- ID: `high_temp_periods`
- Type: `atomic`
- SQL: [`../sql/thermal_module/high_temp_periods.sql`](../sql/thermal_module/high_temp_periods.sql)

```yaml
id: high_temp_periods
type: atomic
display:
  level: detail
  layer: list
  title: 高温时段
save_as: high_temp_periods
```
### 热节流事件

- ID: `throttling_events`
- Type: `atomic`
- SQL: [`../sql/thermal_module/throttling_events.sql`](../sql/thermal_module/throttling_events.sql)

```yaml
id: throttling_events
type: atomic
display:
  level: detail
  layer: list
  title: 频率骤降事件 (可能的热节流)
save_as: throttling_events
```
### 散热设备活动

- ID: `cooling_activity`
- Type: `atomic`
- SQL: [`../sql/thermal_module/cooling_activity.sql`](../sql/thermal_module/cooling_activity.sql)

```yaml
id: cooling_activity
type: atomic
display:
  level: detail
  layer: overview
  title: 散热设备
save_as: cooling_activity
optional: true
```
### 温度-频率相关性

- ID: `thermal_cpu_correlation`
- Type: `atomic`
- SQL: [`../sql/thermal_module/thermal_cpu_correlation.sql`](../sql/thermal_module/thermal_cpu_correlation.sql)

```yaml
id: thermal_cpu_correlation
type: atomic
display:
  level: detail
  layer: list
  title: 温度-频率相关性
save_as: thermal_cpu_correlation
```
### 热管理诊断

- ID: `thermal_diagnosis`
- Type: `diagnostic`

```yaml
id: thermal_diagnosis
type: diagnostic
inputs:
- temp_overview
- high_temp_periods
- throttling_events
- thermal_cpu_correlation
rules:
- condition: temp_overview.data.filter(t => t.status === 'critical').length > 0
  diagnosis: '检测到严重高温: ${temp_overview.data.filter(t => t.status === ''critical'')[0]?.sensor_name} 最高 ${temp_overview.data.filter(t
    => t.status === ''critical'')[0]?.max_temp}°C'
  confidence: critical
  suggestions:
  - 检查设备散热条件
  - 减少 CPU/GPU 密集型操作
  - 考虑添加冷却间隔
  evidence_fields:
  - temp_overview.data[0]?.sensor_name
  - temp_overview.data[0]?.max_temp
- condition: throttling_events.data.length > 10
  diagnosis: 检测到 ${throttling_events.data.length} 次频率骤降，热节流显著影响性能
  confidence: high
  suggestions:
  - 工作负载过高导致热积累
  - 考虑分散计算任务
  - 优化算法减少 CPU 使用
  evidence_fields:
  - throttling_events.data.length
  - throttling_events.data[0]?.drop_pct
- condition: high_temp_periods.data[0]?.duration_sec > 30
  diagnosis: 高温持续 ${high_temp_periods.data[0]?.duration_sec} 秒，散热不足
  confidence: high
  suggestions:
  - 持续高温会加速热节流
  - 检查设备是否被遮挡
  - 考虑降低持续性能需求
  evidence_fields:
  - high_temp_periods.data[0]?.sensor_name
  - high_temp_periods.data[0]?.duration_sec
  - high_temp_periods.data[0]?.peak_temp
- condition: thermal_cpu_correlation.data.filter(t => t.status === 'thermal_throttled').length > 5
  diagnosis: 温度与 CPU 频率呈明显负相关，热节流正在发生
  confidence: high
  suggestions:
  - 高温直接导致 CPU 降频
  - 性能受限于散热能力
  evidence_fields:
  - thermal_cpu_correlation.data.filter(t => t.status === 'thermal_throttled').length
- condition: temp_overview.data[0]?.temp_range > 20
  diagnosis: '温度波动较大: 变化范围 ${temp_overview.data[0]?.temp_range}°C'
  confidence: medium
  suggestions:
  - 工作负载不均匀
  - 检查是否有突发计算任务
  evidence_fields:
  - temp_overview.data[0]?.sensor_name
  - temp_overview.data[0]?.temp_range
display:
  level: key
  layer: overview
  title: 热管理诊断结果
```
