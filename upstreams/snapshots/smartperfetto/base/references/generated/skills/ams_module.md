GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/framework/ams_module.skill.yaml
Source SHA-256: bfd2cd1f208acc814f9da8ed0ec0b02c0d5fd7226da25bec898e8de516e315cd
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
