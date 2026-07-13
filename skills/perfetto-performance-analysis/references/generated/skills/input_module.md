GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/framework/input_module.skill.yaml
Source SHA-256: 77e992fb9b0d483e4e6c1956dd1023052e4c345a03137e372448ad8c22892918
Source commit: 68b113e0355716255af357e8396cd71c71e11d97
# Input 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: input_module
version: '1.0'
type: composite
category: framework
```

## Metadata

```yaml
display_name: Input 分析
description: 分析触摸延迟、输入派发和点击响应
tags:
- framework
- input
- touch
- click
- latency
```

## Prerequisites

```yaml
modules:
- android.input
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: Target package name
- name: ts
  type: timestamp
  required: false
  description: Target timestamp
```

## Module contract

```yaml
layer: framework
component: Input
subsystems:
- input_reader
- input_dispatcher
- input_consumer
relatedModules:
- framework_wms
- framework_surfaceflinger
- app_third_party
```

## Dialogue guidance

```yaml
capabilities:
- id: click_response_analysis
  questionTemplate: What is the click response time for package {package}?
  requiredParams:
  - package
  optionalParams:
  - start_ts
  - end_ts
  description: Analyze touch-to-response latency
- id: input_dispatch_latency
  questionTemplate: Why was input dispatch slow at timestamp {ts}?
  requiredParams:
  - ts
  description: Analyze input dispatch delays
- id: touch_event_flow
  questionTemplate: What happened to touch event at {ts}?
  requiredParams:
  - ts
  description: Trace touch event through the system
findingsSchema:
- id: high_input_latency
  severity: critical
  titleTemplate: 'High input latency: {latency_ms}ms'
  descriptionTemplate: Touch-to-response exceeded threshold ({latency_ms}ms > 100ms)
  evidenceFields:
  - latency_ms
  - dispatch_ms
  - app_handling_ms
- id: input_dispatch_delay
  severity: warning
  titleTemplate: Input dispatch delayed by {dispatch_ms}ms
  descriptionTemplate: InputDispatcher took {dispatch_ms}ms to dispatch event
  evidenceFields:
  - dispatch_ms
  - queue_depth
- id: app_input_handling_slow
  severity: warning
  titleTemplate: 'App input handling slow: {app_handling_ms}ms'
  descriptionTemplate: App took {app_handling_ms}ms to handle input event
  evidenceFields:
  - app_handling_ms
  - main_thread_state
suggestionsSchema:
- id: check_main_thread
  condition: app_handling_ms > 50
  targetModule: scheduler_module
  questionTemplate: Why was main thread slow during input handling?
  paramsMapping:
    package: package
  priority: 1
- id: check_binder_during_input
  condition: binder_during_input > 0
  targetModule: binder_module
  questionTemplate: What Binder calls happened during input handling?
  paramsMapping:
    package: package
  priority: 2
```

## Ordered execution

### 点击响应概览

- ID: `click_response_overview`
- Type: `atomic`
- SQL: [`../sql/input_module/click_response_overview.sql`](../sql/input_module/click_response_overview.sql)

```yaml
id: click_response_overview
type: atomic
display:
  level: key
  layer: overview
  title: 点击响应概览
save_as: click_stats
synthesize:
  role: overview
  fields:
  - key: total_clicks
    label: 总点击数
  - key: avg_latency_ms
    label: 平均延迟
    format: '{{value}}ms'
  - key: slow_clicks
    label: 慢响应数
```
### 慢输入事件

- ID: `slow_input_events`
- Type: `atomic`
- SQL: [`../sql/input_module/slow_input_events.sql`](../sql/input_module/slow_input_events.sql)

```yaml
id: slow_input_events
type: atomic
display:
  level: detail
  layer: list
  title: 慢输入事件列表
save_as: slow_inputs
```
### 输入派发时序

- ID: `input_dispatch_timing`
- Type: `atomic`
- SQL: [`../sql/input_module/input_dispatch_timing.sql`](../sql/input_module/input_dispatch_timing.sql)

```yaml
id: input_dispatch_timing
type: atomic
display:
  level: detail
  layer: overview
  title: 输入派发时序
save_as: dispatch_timing
synthesize: true
```
### 输入诊断

- ID: `input_diagnosis`
- Type: `diagnostic`

```yaml
id: input_diagnosis
type: diagnostic
inputs:
- click_stats
- slow_inputs
- dispatch_timing
rules:
- condition: click_stats.data[0]?.avg_latency_ms > 100
  diagnosis: 平均点击响应延迟过高 (${click_stats.data[0]?.avg_latency_ms}ms)，超过 100ms 阈值
  confidence: high
  suggestions:
  - 检查主线程是否有耗时操作
  - 优化 View 层级减少测量/布局时间
  evidence_fields:
  - click_stats.data[0].avg_latency_ms
  - click_stats.data[0].slow_clicks
- condition: click_stats.data[0]?.slow_clicks > 5
  diagnosis: 存在 ${click_stats.data[0]?.slow_clicks} 次慢响应点击事件
  confidence: high
  suggestions:
  - 分析具体慢点击事件的根因
  - 检查是否有 Binder 调用阻塞
  evidence_fields:
  - click_stats.data[0].slow_clicks
  - click_stats.data[0].max_latency_ms
- condition: dispatch_timing.data.find(s => s.stage === 'InputDispatcher')?.avg_ms > 5
  diagnosis: InputDispatcher 派发延迟 (${dispatch_timing.data.find(s => s.stage === 'InputDispatcher')?.avg_ms}ms)
  confidence: medium
  suggestions:
  - 检查系统负载
  - 检查是否有其他应用占用焦点
  evidence_fields:
  - dispatch_timing.data[1].avg_ms
display:
  level: key
  layer: overview
  title: 输入诊断结果
```
