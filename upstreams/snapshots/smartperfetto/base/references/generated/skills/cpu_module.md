GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/hardware/cpu_module.skill.yaml
Source SHA-256: d035f125f1bd29ac6f675796781f4037254da8283f6dc51f661b1b9e5afaa51e
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d
# CPU 硬件分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_module
version: '1.0'
type: composite
category: hardware
```

## Metadata

```yaml
display_name: CPU 硬件分析
description: 分析 CPU 频率、热节流和电源状态
tags:
- hardware
- cpu
- frequency
- thermal
- power
```

## Prerequisites

```yaml
modules:
- linux.cpu.frequency
- linux.cpu.idle
```

## Inputs

```yaml
- name: cpu_id
  type: number
  required: false
  description: Specific CPU core ID
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
component: CPU
subsystems:
- frequency
- thermal
- power
- cluster
relatedModules:
- kernel_scheduler
- hardware_gpu
- hardware_memory
```

## Dialogue guidance

```yaml
capabilities:
- id: cpu_frequency_analysis
  questionTemplate: What is the CPU frequency during {start_ts} to {end_ts}?
  requiredParams:
  - start_ts
  - end_ts
  optionalParams:
  - cpu_id
  description: Analyze CPU frequency changes and throttling
- id: thermal_throttling
  questionTemplate: Is there thermal throttling affecting performance?
  requiredParams: []
  description: Detect thermal throttling events
- id: cluster_utilization
  questionTemplate: What is the big/little core utilization?
  requiredParams: []
  optionalParams:
  - package
  description: Analyze core cluster usage patterns
- id: cpu_idle_analysis
  questionTemplate: What CPU idle states are being used?
  requiredParams: []
  description: Analyze CPU C-state transitions
findingsSchema:
- id: thermal_throttling_detected
  severity: critical
  titleTemplate: 'Thermal throttling: CPU limited to {max_freq_mhz}MHz'
  descriptionTemplate: CPU frequency capped due to thermal limit ({thermal_zone}°C)
  evidenceFields:
  - max_freq_mhz
  - thermal_zone
  - throttle_duration_ms
- id: low_frequency_operation
  severity: warning
  titleTemplate: 'CPU running at low frequency: avg {avg_freq_mhz}MHz'
  descriptionTemplate: CPU frequency below optimal ({avg_freq_mhz}MHz vs {max_freq_mhz}MHz capacity)
  evidenceFields:
  - avg_freq_mhz
  - max_freq_mhz
  - time_at_low_freq_pct
- id: inefficient_cluster_usage
  severity: warning
  titleTemplate: 'Inefficient cluster usage: {small_core_pct}% on small cores'
  descriptionTemplate: Performance-critical work running on efficiency cores
  evidenceFields:
  - small_core_pct
  - big_core_pct
  - total_cpu_time_ms
- id: frequent_frequency_changes
  severity: info
  titleTemplate: 'Frequent frequency changes: {change_count} transitions'
  descriptionTemplate: CPU frequency changing rapidly, possible governor issue
  evidenceFields:
  - change_count
  - avg_duration_between_changes_ms
suggestionsSchema:
- id: check_thermal_zone
  condition: thermal_throttling == true
  targetModule: thermal_module
  questionTemplate: What is causing thermal throttling?
  paramsMapping: {}
  priority: 1
- id: check_power_state
  condition: low_power_mode == true
  targetModule: power_module
  questionTemplate: Is power saving mode affecting CPU performance?
  paramsMapping: {}
  priority: 2
```

## Ordered execution

### 初始化 CPU 拓扑

- ID: `init_cpu_topology`
- Type: `skill`

```yaml
id: init_cpu_topology
type: skill
skill: cpu_topology_view
display:
  level: hidden
optional: true
```
### CPU 频率概览

- ID: `frequency_overview`
- Type: `atomic`
- SQL: [`../sql/cpu_module/frequency_overview.sql`](../sql/cpu_module/frequency_overview.sql)

```yaml
id: frequency_overview
type: atomic
display:
  level: key
  layer: overview
  title: CPU 频率概览
save_as: freq_overview
synthesize:
  role: overview
  groupBy:
  - field: cluster
    title: 核心集群
```
### 频率限制事件

- ID: `throttling_events`
- Type: `atomic`
- SQL: [`../sql/cpu_module/throttling_events.sql`](../sql/cpu_module/throttling_events.sql)

```yaml
id: throttling_events
type: atomic
display:
  level: detail
  layer: list
  title: 频率变化事件
save_as: throttle_events
```
### 集群利用率

- ID: `cluster_utilization`
- Type: `atomic`
- SQL: [`../sql/cpu_module/cluster_utilization.sql`](../sql/cpu_module/cluster_utilization.sql)

```yaml
id: cluster_utilization
type: atomic
display:
  level: detail
  layer: overview
  title: 集群利用率
save_as: cluster_util
synthesize: true
```
### 频率分布

- ID: `frequency_distribution`
- Type: `atomic`
- SQL: [`../sql/cpu_module/frequency_distribution.sql`](../sql/cpu_module/frequency_distribution.sql)

```yaml
id: frequency_distribution
type: atomic
display:
  level: detail
  layer: list
  title: 频率分布
save_as: freq_dist
```
### CPU 诊断

- ID: `cpu_diagnosis`
- Type: `diagnostic`

```yaml
id: cpu_diagnosis
type: diagnostic
inputs:
- freq_overview
- throttle_events
- cluster_util
rules:
- condition: freq_overview.data.find(f => f.cluster === 'big')?.avg_freq_mhz < 1500
  diagnosis: 大核 CPU 平均频率较低 (${freq_overview.data.find(f => f.cluster === 'big')?.avg_freq_mhz}MHz)，可能存在热节流或功耗限制
  confidence: high
  suggestions:
  - 检查设备温度
  - 检查是否开启省电模式
  evidence_fields:
  - freq_overview.data[0].avg_freq_mhz
  - freq_overview.data[0].max_freq_mhz
- condition: throttle_events.data.length > 20
  diagnosis: CPU 频率频繁变化 (${throttle_events.data.length} 次)，调度器可能不稳定
  confidence: medium
  suggestions:
  - 检查 governor 设置
  - 检查是否有功耗抖动
  evidence_fields:
  - throttle_events.data.length
- condition: freq_overview.data.find(f => f.cluster === 'little')?.avg_freq_mhz > freq_overview.data.find(f => f.cluster ===
    'big')?.avg_freq_mhz
  diagnosis: 小核频率高于大核，可能存在调度异常或热节流
  confidence: medium
  suggestions:
  - 检查大核是否被热节流
  - 检查 CPU affinity 设置
  evidence_fields:
  - freq_overview.data[0].avg_freq_mhz
display:
  level: key
  layer: overview
  title: CPU 诊断结果
```
