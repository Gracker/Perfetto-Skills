GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/hardware/thermal_module.skill.yaml
Source SHA-256: 8c83bc8520dbf3876468ade4e67ed590a9be89022763464315e08cd82452b23a
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
    label: 样本平均温度
    format: '{{value}}'
  - key: max_temp
    label: 最高温度
    format: '{{value}}'
  - key: source_unit
    label: 原始单位
  - key: status
    label: 状态
on_empty: 窗口内未找到温度样本；检查 trace 是否包含 thermal/temperature 计数器。缺少单位时不进行摄氏温度阈值判断。
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
  title: 高温样本跨度
save_as: high_temp_periods
```
### 频率骤降事件

- ID: `throttling_events`
- Type: `atomic`
- SQL: [`../sql/thermal_module/throttling_events.sql`](../sql/thermal_module/throttling_events.sql)

```yaml
id: throttling_events
type: atomic
display:
  level: detail
  layer: list
  title: 频率骤降事件（原因待查）
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
  severity: critical
  confidence: high
  suggestions:
  - 检查设备散热条件
  - 减少 CPU/GPU 密集型操作
  - 考虑添加冷却间隔
  evidence_fields:
  - temp_overview.data[0]?.sensor_name
  - temp_overview.data[0]?.max_temp
- condition: throttling_events.data.length > 10
  diagnosis: 检测到 ${throttling_events.data.length} 次频率骤降；尚不能据此确定热节流或性能影响
  confidence: high
  suggestions:
  - 结合直接 thermal throttling/cooling 事件和同窗口工作负载判断降频原因
  - 考虑分散计算任务
  - 优化算法减少 CPU 使用
  evidence_fields:
  - throttling_events.data.length
  - throttling_events.data[0]?.drop_pct
- condition: high_temp_periods.data[0]?.duration_sec > 30
  diagnosis: 高温样本首尾跨度 ${high_temp_periods.data[0]?.duration_sec} 秒；不代表连续高温或散热不足
  confidence: high
  suggestions:
  - 持续高温会加速热节流
  - 检查设备是否被遮挡
  - 考虑降低持续性能需求
  evidence_fields:
  - high_temp_periods.data[0]?.sensor_name
  - high_temp_periods.data[0]?.duration_sec
  - high_temp_periods.data[0]?.peak_temp
- condition: thermal_cpu_correlation.data.filter(t => t.status === 'high_temperature_with_low_sampled_frequency').length >
    5
  diagnosis: 同一秒内观测到高温和较低的频率样本；这种并存不能证明热节流或负相关
  confidence: high
  suggestions:
  - 查找温控限制、冷却状态或限频事件的直接证据
  - 结合目标任务窗口和负载变化检验性能影响
  evidence_fields:
  - thermal_cpu_correlation.data.filter(t => t.status === 'high_temperature_with_low_sampled_frequency').length
- condition: temp_overview.data[0]?.temp_range > 20
  diagnosis: 温度计数器样本变化范围 ${temp_overview.data[0]?.temp_range}，原始单位 ${temp_overview.data[0]?.source_unit}
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
