GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/framework/ams_module.skill.yaml
Source SHA-256: a39931677061435b7e6004f603fa590fc51196fd1619697154b7f89e5c1510ec
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# AMS 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: ams_module
version: '1.0'
type: composite
category: framework
```

## Metadata

```yaml
display_name: AMS 分析
description: 分析应用生命周期、进程管理和启动时序
tags:
- framework
- ams
- lifecycle
- startup
- anr
```

## Prerequisites

```yaml
modules:
- android.startup.startups
- android.startup.time_to_display
- android.broadcasts
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: Target package name
- name: launch_type
  type: string
  required: false
  description: 'Launch type: cold, warm, hot'
```

## Module contract

```yaml
layer: framework
component: AMS
subsystems:
- activity_lifecycle
- process_management
- broadcast
- service
relatedModules:
- kernel_scheduler
- framework_wms
- app_third_party
```

## Dialogue guidance

```yaml
capabilities:
- id: startup_timing
  questionTemplate: What is the startup timing breakdown for package {package}?
  requiredParams:
  - package
  optionalParams:
  - launch_type
  description: Analyze cold/warm/hot startup timing
- id: activity_lifecycle
  questionTemplate: What activity transitions happened for package {package}?
  requiredParams:
  - package
  optionalParams:
  - start_ts
  - end_ts
  description: Analyze activity lifecycle events
- id: process_start
  questionTemplate: Why was process {package} slow to start?
  requiredParams:
  - package
  description: Analyze process creation delays
- id: anr_analysis
  questionTemplate: Why did package {package} ANR?
  requiredParams:
  - package
  description: Analyze ANR root cause
findingsSchema:
- id: slow_startup
  severity: critical
  titleTemplate: 'Slow startup: {launch_type} took {total_ms}ms'
  descriptionTemplate: App startup exceeded threshold ({total_ms}ms > {threshold_ms}ms)
  evidenceFields:
  - launch_type
  - total_ms
  - ttid_ms
  - ttfd_ms
  - threshold_ms
- id: broadcast_delay
  severity: warning
  titleTemplate: Broadcast receiver delayed startup by {delay_ms}ms
  descriptionTemplate: Broadcast {broadcast_action} blocked startup
  evidenceFields:
  - broadcast_action
  - delay_ms
- id: content_provider_slow
  severity: warning
  titleTemplate: 'ContentProvider initialization slow: {provider_ms}ms'
  descriptionTemplate: ContentProvider {provider_name} took {provider_ms}ms to initialize
  evidenceFields:
  - provider_name
  - provider_ms
- id: anr_detected
  severity: critical
  titleTemplate: 'ANR detected: {anr_type}'
  descriptionTemplate: Application Not Responding due to {anr_cause}
  evidenceFields:
  - anr_type
  - anr_cause
  - blocked_ms
suggestionsSchema:
- id: check_gc_during_startup
  condition: gc_during_startup > 0
  targetModule: art_module
  questionTemplate: Was GC causing startup delay for {package}?
  paramsMapping:
    package: package
  priority: 1
- id: check_binder_during_startup
  condition: binder_during_startup_ms > 50
  targetModule: binder_module
  questionTemplate: What Binder calls delayed startup for {package}?
  paramsMapping:
    package: package
  priority: 1
- id: check_io_during_startup
  condition: io_wait_ms > 100
  targetModule: filesystem_module
  questionTemplate: What IO operations delayed startup?
  paramsMapping:
    package: package
  priority: 2
```

## Ordered execution

### 启动时序分析

- ID: `startup_timing`
- Type: `atomic`
- SQL: [`../sql/ams_module/startup_timing.sql`](../sql/ams_module/startup_timing.sql)

```yaml
id: startup_timing
type: atomic
display:
  level: key
  layer: overview
  title: 启动时序
save_as: startup_data
synthesize:
  role: overview
  fields:
  - key: launch_type
    label: 启动类型
  - key: total_ms
    label: 总耗时
    format: '{{value}}ms'
  - key: ttid_ms
    label: 首帧显示
    format: '{{value}}ms'
```
### 启动阶段分解

- ID: `startup_phases`
- Type: `atomic`
- SQL: [`../sql/ams_module/startup_phases.sql`](../sql/ams_module/startup_phases.sql)

```yaml
id: startup_phases
type: atomic
display:
  level: detail
  layer: list
  title: 启动阶段
save_as: phases
```
### 广播分析

- ID: `broadcast_analysis`
- Type: `atomic`
- SQL: [`../sql/ams_module/broadcast_analysis.sql`](../sql/ams_module/broadcast_analysis.sql)

```yaml
id: broadcast_analysis
type: atomic
display:
  level: detail
  layer: list
  title: 启动期间广播
save_as: broadcasts
```
### 启动诊断

- ID: `startup_diagnosis`
- Type: `diagnostic`

```yaml
id: startup_diagnosis
type: diagnostic
inputs:
- startup_data
- phases
- broadcasts
rules:
- condition: startup_data.data[0]?.total_ms > 1000 && startup_data.data[0]?.launch_type === 'cold'
  diagnosis: 冷启动耗时过长 (${startup_data.data[0]?.total_ms}ms)，超过 1 秒阈值
  confidence: high
  suggestions:
  - 检查 Application.onCreate() 耗时
  - 延迟非必要初始化
  evidence_fields:
  - startup_data.data[0].total_ms
  - startup_data.data[0].launch_type
- condition: startup_data.data[0]?.total_ms > 500 && startup_data.data[0]?.launch_type === 'warm'
  diagnosis: 温启动耗时过长 (${startup_data.data[0]?.total_ms}ms)，超过 500ms 阈值
  confidence: medium
  suggestions:
  - 检查 Activity.onCreate() 耗时
  - 优化布局复杂度
  evidence_fields:
  - startup_data.data[0].total_ms
- condition: broadcasts.data[0]?.dur_ms > 50
  diagnosis: 广播接收器延迟启动 (${broadcasts.data[0]?.broadcast_action} 耗时 ${broadcasts.data[0]?.dur_ms}ms)
  confidence: medium
  suggestions:
  - 将广播处理移至后台
  - 考虑使用 JobScheduler
  evidence_fields:
  - broadcasts.data[0].broadcast_action
  - broadcasts.data[0].dur_ms
display:
  level: key
  layer: overview
  title: 启动诊断结果
```
