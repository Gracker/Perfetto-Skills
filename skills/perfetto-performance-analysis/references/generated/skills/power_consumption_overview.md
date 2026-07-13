GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/power_consumption_overview.skill.yaml
Source SHA-256: 500e56c35f463dfbfe88e8ac5f45c7882c5010b2212f2139e5b421f659d1b6f2
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# 功耗总览分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: power_consumption_overview
version: '1.0'
type: composite
category: power
tier: S
```

## Metadata

```yaml
display_name: 功耗总览分析
description: 组合 Wattson rail/thread、battery、wakelock、DVFS、GPU work period 等证据，输出功耗问题总览
icon: battery_charging_full
tags:
- power
- wattson
- battery
- wakelock
- dvfs
- overview
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 功耗总览
  - 耗电总览
  - 电池分析
  - rail 归因
  - wattson
  - 待机耗电
  en:
  - power overview
  - battery drain overview
  - wattson
  - rail attribution
  - energy analysis
patterns:
- .*(功耗|耗电|电池).*(总览|归因|分析).*
- .*(power|battery|energy).*(overview|attribution|analysis).*
```

## Prerequisites

```yaml
modules:
- android.power_rails
- wattson.aggregation
- android.battery
- android.kernel_wakelocks
- android.wakeups
- android.screen_state
- android.network_packets
- linux.cpu.idle
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

### Power Rails 实测能耗

- ID: `hardware_rails`
- Type: `skill`

```yaml
id: hardware_rails
type: skill
skill: power_rails_energy_breakdown
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: summary
save_as: hardware_rails
optional: true
```
### Wattson 子系统能耗估算

- ID: `wattson_rails`
- Type: `skill`

```yaml
id: wattson_rails
type: skill
skill: wattson_rails_power_breakdown
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: summary
save_as: wattson_rails
optional: true
```
### 掉电速率摘要

- ID: `battery_drain_rate`
- Type: `skill`

```yaml
id: battery_drain_rate
type: skill
skill: battery_drain_rate_summary
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: summary
save_as: battery_drain_rate
optional: true
```
### Suspend / Wakeup 链路

- ID: `suspend_wakeup`
- Type: `skill`

```yaml
id: suspend_wakeup
type: skill
skill: suspend_wakeup_analysis
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: summary
save_as: suspend_wakeup
optional: true
```
### 唤醒频率摘要

- ID: `wakeup_frequency`
- Type: `skill`

```yaml
id: wakeup_frequency
type: skill
skill: wakeup_frequency_summary
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: summary
save_as: wakeup_frequency
optional: true
```
### Kernel Wakelock 汇总

- ID: `wakelocks`
- Type: `skill`

```yaml
id: wakelocks
type: skill
skill: android_kernel_wakelock_summary
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: wakelocks
optional: true
```
### 熄屏后台 CPU 归因

- ID: `screen_off_cpu`
- Type: `skill`

```yaml
id: screen_off_cpu
type: skill
skill: screen_off_background_cpu_attribution
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: screen_off_cpu
optional: true
```
### Modem / 网络相关性

- ID: `modem_network`
- Type: `skill`

```yaml
id: modem_network
type: skill
skill: modem_network_correlation_summary
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: modem_network
optional: true
```
### CPU 高频驻留

- ID: `cpu_freq_residency`
- Type: `skill`

```yaml
id: cpu_freq_residency
type: skill
skill: cpu_freq_residency_summary
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: cpu_freq_residency
optional: true
```
### Wattson 线程能耗归因

- ID: `wattson_threads`
- Type: `skill`

```yaml
id: wattson_threads
type: skill
skill: wattson_thread_power_attribution
params:
  package: ${package}
  process_name: ${process_name}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: wattson_threads
optional: true
```
### 电池电量/电流时间线

- ID: `battery_charge`
- Type: `skill`

```yaml
id: battery_charge
type: skill
skill: battery_charge_timeline
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: battery_charge
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
## Output and evidence contract

```yaml
format: structured
```
