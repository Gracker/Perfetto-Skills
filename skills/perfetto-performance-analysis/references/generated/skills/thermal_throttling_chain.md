GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/thermal_throttling_chain.skill.yaml
Source SHA-256: 840d149570c40efdadb929920141eec03d3e578709be09c9bc99fa3510efd39f
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# 温控降频链路分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: thermal_throttling_chain
version: '1.0'
type: composite
category: power
tier: S
```

## Metadata

```yaml
display_name: 温控降频链路分析
description: 组合温度、DVFS、CPU idle/util、GPU work period 和 Mali power state，分析热节流因果链
icon: device_thermostat
tags:
- thermal
- throttling
- dvfs
- cpu
- gpu
- power
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 温控链路
  - 热节流链路
  - 发热掉帧
  - 降频原因
  - 温度导致卡顿
  en:
  - thermal throttling chain
  - heat jank
  - frequency cap
  - thermal cause
patterns:
- .*(温控|热节流|发热).*(链路|原因|卡顿|掉帧).*
- .*thermal.*(chain|cause|jank|throttl).*
```

## Prerequisites

```yaml
modules:
- android.dvfs
- linux.cpu.idle
- linux.cpu.utilization.process
- linux.cpu.utilization.thread
- android.gpu.work_period
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标进程名（可选）
- name: process_name
  type: string
  required: false
  description: 目标进程名别名；当 package 为空时使用
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
```

## Ordered execution

### 温度/热节流分析

- ID: `thermal`
- Type: `skill`

```yaml
id: thermal
type: skill
skill: thermal_throttling
params:
  package: ${package|${process_name|}}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: summary
save_as: thermal
optional: true
```
### DVFS 频率统计

- ID: `dvfs`
- Type: `skill`

```yaml
id: dvfs
type: skill
skill: android_dvfs_counter_stats
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: dvfs
optional: true
```
### CPU Idle Residency

- ID: `cpu_idle`
- Type: `skill`

```yaml
id: cpu_idle
type: skill
skill: cpu_idle_state_residency
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: cpu_idle
optional: true
```
### 进程 CPU 利用率

- ID: `process_util`
- Type: `skill`

```yaml
id: process_util
type: skill
skill: cpu_process_utilization_period
params:
  package: ${package|${process_name|}}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: process_util
optional: true
```
### 线程 CPU 利用率

- ID: `thread_util`
- Type: `skill`

```yaml
id: thread_util
type: skill
skill: cpu_thread_utilization_period
params:
  package: ${package|${process_name|}}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: thread_util
optional: true
```
### GPU Work Period

- ID: `gpu_work_period`
- Type: `skill`

```yaml
id: gpu_work_period
type: skill
skill: android_gpu_work_period_track
params:
  package: ${package|${process_name|}}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: gpu_work_period
optional: true
```
### Mali Power State

- ID: `mali_state`
- Type: `skill`

```yaml
id: mali_state
type: skill
skill: mali_gpu_power_state
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: mali_state
optional: true
```
## Output and evidence contract

```yaml
format: structured
```
