GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/battery_drain_attribution.skill.yaml
Source SHA-256: d35668e7c2d4eb757ad7b58857fef582f741e61dd8617d0941fbd2072ed61819
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# 掉电归因分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: battery_drain_attribution
version: '1.0'
type: composite
category: power
tier: S
```

## Metadata

```yaml
display_name: 掉电归因分析
description: 组合 battery、Doze、wakelock、job、network、suspend/wakeup 证据，分析掉电和待机耗电原因
icon: battery_alert
tags:
- battery
- drain
- wakelock
- doze
- network
- job
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 掉电
  - 待机耗电
  - 电池掉
  - wakelock
  - Doze
  - 后台耗电
  en:
  - battery drain
  - standby drain
  - wakelock
  - doze
  - background power
patterns:
- .*(掉电|待机耗电|后台耗电).*
- .*battery.*drain.*
- .*standby.*drain.*
```

## Prerequisites

```yaml
modules:
- android.battery
- android.battery.doze
- android.kernel_wakelocks
- android.wakeups
- android.screen_state
- android.job_scheduler
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
### 电池采样

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
  level: summary
save_as: battery_charge
optional: true
```
### Doze 状态

- ID: `doze_state`
- Type: `skill`

```yaml
id: doze_state
type: skill
skill: battery_doze_state_timeline
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: doze_state
optional: true
```
### Wakelock 汇总

- ID: `wakelock_summary`
- Type: `skill`

```yaml
id: wakelock_summary
type: skill
skill: android_kernel_wakelock_summary
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: wakelock_summary
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
### 熄屏后台 CPU

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
### Suspend/Wakeup 链路

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
  level: detail
save_as: suspend_wakeup
optional: true
```
### JobScheduler 事件

- ID: `job_scheduler`
- Type: `skill`

```yaml
id: job_scheduler
type: skill
skill: android_job_scheduler_events
params:
  package: ${package|${process_name|}}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: job_scheduler
optional: true
```
### 网络活动

- ID: `network_activity`
- Type: `skill`

```yaml
id: network_activity
type: skill
skill: network_analysis
params:
  package: ${package}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: network_activity
optional: true
```
### Modem / 蜂窝网络相关性

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
## Output and evidence contract

```yaml
format: structured
```
