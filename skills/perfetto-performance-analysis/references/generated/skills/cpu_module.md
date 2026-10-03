GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/hardware/cpu_module.skill.yaml
Source SHA-256: 4a9d6de50b0314b731792232ca2a3ac602c68e7c870a4e4a3d95f97d9f84a688
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
description: 分析 CPU 频率、频率变化和电源状态
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
### 频率变化事件

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
  title_i18n:
    en: Frequency Change Events
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
  diagnosis: 大核 CPU 平均频率较低 (${freq_overview.data.find(f => f.cluster === 'big')?.avg_freq_mhz}MHz)；仅为频率观测，低频可能来自负载、调速器或频率上限
  confidence: high
  suggestions:
  - 是否限频以同窗口的 CPU 限频证据（cpu_throttling_in_range）为准
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
  diagnosis: 小核平均频率高于大核；仅为频率观测，可能来自两簇负载不同或大核频率上限
  confidence: medium
  suggestions:
  - 是否限频以同窗口的 CPU 限频证据（cpu_throttling_in_range）为准
  - 检查 CPU affinity 设置
  evidence_fields:
  - freq_overview.data[0].avg_freq_mhz
display:
  level: key
  layer: overview
  title: CPU 诊断结果
```
