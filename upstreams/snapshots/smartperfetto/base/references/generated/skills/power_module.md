GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/hardware/power_module.skill.yaml
Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# 电源管理分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: power_module
version: '1.0'
type: composite
category: hardware
```

## Metadata

```yaml
display_name: 电源管理分析
description: 分析 Wakelock、CPU 空闲状态和电源策略
tags:
- hardware
- power
- wakelock
- idle
- suspend
- battery
```

## Prerequisites

```yaml
required_tables:
- counter
- counter_track
optional_tables:
- slice
- android_suspend_resume
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: Target package name
```

## Module contract

```yaml
layer: hardware
component: Power
subsystems:
- wakelock
- cpu_idle
- power_mode
- suspend_resume
relatedModules:
- hardware_cpu
- kernel_scheduler
- framework_ams
```

## Dialogue guidance

```yaml
capabilities:
- id: wakelock_analysis
  questionTemplate: What wakelocks are held by package {package}?
  requiredParams: []
  optionalParams:
  - package
  description: Analyze wakelock usage patterns
- id: cpu_idle_analysis
  questionTemplate: What CPU idle states are being used?
  requiredParams: []
  description: Analyze CPU C-state transitions
- id: power_mode_changes
  questionTemplate: Were there any power mode changes during the trace?
  requiredParams: []
  description: Detect power/battery mode changes
- id: suspend_resume_timing
  questionTemplate: What are the suspend/resume timings?
  requiredParams: []
  description: Analyze device suspend/resume behavior
- id: power_efficiency
  questionTemplate: Is the power usage efficient?
  requiredParams: []
  description: Assess overall power efficiency
findingsSchema:
- id: long_wakelock
  severity: warning
  titleTemplate: 'Long wakelock: {wakelock_name} held for {duration_ms}ms'
  descriptionTemplate: Wakelock preventing device sleep
  evidenceFields:
  - wakelock_name
  - duration_ms
  - holder_process
- id: cpu_never_idle
  severity: warning
  titleTemplate: CPU {cpu_id} never reached deep idle
  descriptionTemplate: CPU not entering power-saving states
  evidenceFields:
  - cpu_id
  - shallow_idle_pct
  - deep_idle_pct
- id: frequent_wakeups
  severity: warning
  titleTemplate: 'Frequent wakeups: {wakeup_count} times'
  descriptionTemplate: Device waking frequently, impacting battery
  evidenceFields:
  - wakeup_count
  - avg_sleep_duration_ms
- id: inefficient_power_usage
  severity: info
  titleTemplate: Inefficient power pattern detected
  descriptionTemplate: Power usage could be optimized
  evidenceFields:
  - issue_type
  - recommendation
suggestionsSchema:
- id: check_cpu_frequency
  condition: cpu_not_idle == true
  targetModule: cpu_module
  questionTemplate: Why is CPU not entering idle state?
  paramsMapping: {}
  priority: 1
- id: check_scheduler
  condition: frequent_wakeups > 10
  targetModule: scheduler_module
  questionTemplate: What is waking up the CPU?
  paramsMapping: {}
  priority: 1
```

## Ordered execution

### Wakelock 概览

- ID: `wakelock_overview`
- Type: `atomic`
- SQL: [`../sql/power_module/wakelock_overview.sql`](../sql/power_module/wakelock_overview.sql)

```yaml
id: wakelock_overview
type: atomic
display:
  level: key
  layer: overview
  title: Wakelock 统计
save_as: wakelock_overview
synthesize:
  role: overview
  fields:
  - key: wakelock_event
    label: Wakelock
  - key: event_count
    label: 次数
  - key: total_ms
    label: 总持有时间
    format: '{{value}}ms'
on_empty: 未检测到 Wakelock 事件
```
### 长时间 Wakelock

- ID: `long_wakelocks`
- Type: `atomic`
- SQL: [`../sql/power_module/long_wakelocks.sql`](../sql/power_module/long_wakelocks.sql)

```yaml
id: long_wakelocks
type: atomic
display:
  level: detail
  layer: list
  title: 长时间持有的 Wakelock
save_as: long_wakelocks
```
### CPU 空闲状态

- ID: `cpu_idle_states`
- Type: `atomic`
- SQL: [`../sql/power_module/cpu_idle_states.sql`](../sql/power_module/cpu_idle_states.sql)

```yaml
id: cpu_idle_states
type: atomic
display:
  level: detail
  layer: overview
  title: CPU 空闲状态
save_as: cpu_idle_states
optional: true
```
### 休眠/唤醒事件

- ID: `suspend_resume`
- Type: `atomic`
- SQL: [`../sql/power_module/suspend_resume.sql`](../sql/power_module/suspend_resume.sql)

```yaml
id: suspend_resume
type: atomic
display:
  level: detail
  layer: list
  title: 休眠/唤醒事件
save_as: suspend_resume
```
### 电源计数器

- ID: `power_counters`
- Type: `atomic`
- SQL: [`../sql/power_module/power_counters.sql`](../sql/power_module/power_counters.sql)

```yaml
id: power_counters
type: atomic
display:
  level: detail
  layer: overview
  title: 电源计数器
save_as: power_counters
```
### 电源模式变化

- ID: `power_mode_events`
- Type: `atomic`
- SQL: [`../sql/power_module/power_mode_events.sql`](../sql/power_module/power_mode_events.sql)

```yaml
id: power_mode_events
type: atomic
display:
  level: detail
  layer: list
  title: 电源模式变化
save_as: power_mode_events
```
### 唤醒源

- ID: `wakeup_sources`
- Type: `atomic`
- SQL: [`../sql/power_module/wakeup_sources.sql`](../sql/power_module/wakeup_sources.sql)

```yaml
id: wakeup_sources
type: atomic
display:
  level: detail
  layer: list
  title: 唤醒源
save_as: wakeup_sources
```
### 电源诊断

- ID: `power_diagnosis`
- Type: `diagnostic`

```yaml
id: power_diagnosis
type: diagnostic
inputs:
- wakelock_overview
- long_wakelocks
- cpu_idle_states
- suspend_resume
- wakeup_sources
rules:
- condition: long_wakelocks.data.length > 0
  diagnosis: 检测到 ${long_wakelocks.data.length} 个长时间持有的 Wakelock，最长 ${long_wakelocks.data[0]?.dur_ms}ms
  confidence: high
  suggestions:
  - 检查 Wakelock 是否必要
  - 确保在完成任务后释放 Wakelock
  - 考虑使用 WorkManager 替代
  evidence_fields:
  - long_wakelocks.data.length
  - long_wakelocks.data[0]?.wakelock_name
  - long_wakelocks.data[0]?.dur_ms
- condition: wakelock_overview.data[0]?.total_ms > 10000
  diagnosis: Wakelock 总持有时间 ${wakelock_overview.data[0]?.total_ms}ms，电量消耗较高
  confidence: high
  suggestions:
  - 优化 Wakelock 使用策略
  - 减少不必要的唤醒
  evidence_fields:
  - wakelock_overview.data[0]?.wakelock_event
  - wakelock_overview.data[0]?.total_ms
- condition: wakeup_sources.data[0]?.wakeup_count > 20
  diagnosis: '唤醒次数过多: ${wakeup_sources.data[0]?.wakeup_source} 唤醒了 ${wakeup_sources.data[0]?.wakeup_count} 次'
  confidence: medium
  suggestions:
  - 合并定时任务减少唤醒
  - 使用 AlarmManager.setInexactRepeating()
  evidence_fields:
  - wakeup_sources.data[0]?.wakeup_source
  - wakeup_sources.data[0]?.wakeup_count
- condition: suspend_resume.data.length < 2
  diagnosis: 设备未进入深度休眠，电量消耗增加
  confidence: medium
  suggestions:
  - 检查是否有前台服务阻止休眠
  - 检查 Wakelock 使用情况
  evidence_fields:
  - suspend_resume.data.length
- condition: cpu_idle_states.data[0]?.avg_value < 50
  diagnosis: CPU 空闲状态使用不充分
  confidence: medium
  suggestions:
  - 检查后台任务是否过多
  - 优化定时器触发频率
  evidence_fields:
  - cpu_idle_states.data[0]?.idle_state
  - cpu_idle_states.data[0]?.avg_value
display:
  level: key
  layer: overview
  title: 电源诊断结果
```
