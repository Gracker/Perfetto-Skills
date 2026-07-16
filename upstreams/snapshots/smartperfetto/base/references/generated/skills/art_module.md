GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/framework/art_module.skill.yaml
Source SHA-256: d1467599deb13369b60c04f0f0e38ee4ce36e11b4e96df90b7f409300d451d3f
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# ART 运行时分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: art_module
version: '1.0'
type: composite
category: framework
```

## Metadata

```yaml
display_name: ART 运行时分析
description: 分析 GC、JIT 编译和内存分配
tags:
- framework
- art
- gc
- jit
- memory
```

## Inputs

```yaml
- name: package
  type: string
  required: true
  description: Target package name
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
layer: framework
component: ART
subsystems:
- gc
- jit
- allocation
relatedModules:
- app_third_party
- kernel_scheduler
- hardware_memory
```

## Dialogue guidance

```yaml
capabilities:
- id: gc_analysis
  questionTemplate: What GC activity happened for package {package}?
  requiredParams:
  - package
  optionalParams:
  - start_ts
  - end_ts
  description: Analyze garbage collection events
- id: gc_during_frame
  questionTemplate: Was there GC during frame rendering for {package}?
  requiredParams:
  - package
  description: Check for GC during critical rendering
- id: jit_analysis
  questionTemplate: What JIT compilation happened for package {package}?
  requiredParams:
  - package
  description: Analyze JIT compilation activity
- id: allocation_analysis
  questionTemplate: What are the allocation patterns for package {package}?
  requiredParams:
  - package
  description: Analyze memory allocation patterns
findingsSchema:
- id: gc_during_animation
  severity: critical
  titleTemplate: 'GC during animation: {gc_count} GCs totaling {gc_ms}ms'
  descriptionTemplate: Garbage collection happened during animation, causing jank
  evidenceFields:
  - gc_count
  - gc_ms
  - gc_type
- id: high_gc_frequency
  severity: warning
  titleTemplate: 'High GC frequency: {gc_per_sec} GCs/second'
  descriptionTemplate: Excessive GC activity indicates high allocation rate
  evidenceFields:
  - gc_per_sec
  - total_gc_count
  - avg_gc_ms
- id: long_gc_pause
  severity: warning
  titleTemplate: 'Long GC pause: {max_gc_ms}ms'
  descriptionTemplate: GC pause exceeded 10ms threshold
  evidenceFields:
  - max_gc_ms
  - gc_type
- id: jit_compilation_blocking
  severity: warning
  titleTemplate: 'JIT compilation blocking: {jit_ms}ms'
  descriptionTemplate: JIT compilation blocked main thread
  evidenceFields:
  - jit_ms
  - method_count
suggestionsSchema:
- id: check_allocation_rate
  condition: gc_per_sec > 2
  targetModule: memory_module
  questionTemplate: What is causing high allocation rate for {package}?
  paramsMapping:
    package: package
  priority: 1
- id: check_heap_size
  condition: heap_near_limit == true
  targetModule: memory_module
  questionTemplate: Is heap size limit affecting {package}?
  paramsMapping:
    package: package
  priority: 2
```

## Ordered execution

### GC 概览

- ID: `gc_overview`
- Type: `atomic`
- SQL: [`../sql/art_module/gc_overview.sql`](../sql/art_module/gc_overview.sql)

```yaml
id: gc_overview
type: atomic
display:
  level: key
  layer: overview
  title: GC 概览
save_as: gc_overview
synthesize:
  role: overview
  fields:
  - key: gc_type
    label: GC 类型
  - key: gc_count
    label: 次数
  - key: total_gc_ms
    label: 总耗时
    format: '{{value}}ms'
```
### GC 事件列表

- ID: `gc_events`
- Type: `atomic`
- SQL: [`../sql/art_module/gc_events.sql`](../sql/art_module/gc_events.sql)

```yaml
id: gc_events
type: atomic
display:
  level: detail
  layer: list
  title: GC 事件列表
save_as: gc_events
```
### 主线程 GC

- ID: `gc_during_main_thread`
- Type: `atomic`
- SQL: [`../sql/art_module/gc_during_main_thread.sql`](../sql/art_module/gc_during_main_thread.sql)

```yaml
id: gc_during_main_thread
type: atomic
display:
  level: detail
  layer: list
  title: 主线程 GC
save_as: main_thread_gc
```
### JIT 编译事件

- ID: `jit_events`
- Type: `atomic`
- SQL: [`../sql/art_module/jit_events.sql`](../sql/art_module/jit_events.sql)

```yaml
id: jit_events
type: atomic
display:
  level: detail
  layer: overview
  title: JIT 编译事件
save_as: jit_events
```
### ART 诊断

- ID: `art_diagnosis`
- Type: `diagnostic`

```yaml
id: art_diagnosis
type: diagnostic
inputs:
- gc_overview
- gc_events
- main_thread_gc
- jit_events
rules:
- condition: main_thread_gc.data.length > 0
  diagnosis: 主线程发生 ${main_thread_gc.data.length} 次 GC，可能导致卡顿
  confidence: high
  suggestions:
  - 减少临时对象分配
  - 使用对象池复用对象
  evidence_fields:
  - main_thread_gc.data.length
  - main_thread_gc.data[0]?.dur_ms
- condition: gc_overview.data[0]?.total_gc_ms > 100
  diagnosis: GC 总耗时过长 (${gc_overview.data[0]?.total_gc_ms}ms)，内存压力大
  confidence: high
  suggestions:
  - 检查是否有内存泄漏
  - 优化数据结构减少内存使用
  evidence_fields:
  - gc_overview.data[0].total_gc_ms
  - gc_overview.data[0].gc_count
- condition: gc_events.data[0]?.dur_ms > 10
  diagnosis: 存在长 GC 暂停 (${gc_events.data[0]?.dur_ms}ms)
  confidence: medium
  suggestions:
  - 增加堆大小
  - 避免在关键路径分配大对象
  evidence_fields:
  - gc_events.data[0].dur_ms
  - gc_events.data[0].gc_type
- condition: jit_events.data[0]?.total_ms > 50
  diagnosis: JIT 编译耗时较长 (${jit_events.data[0]?.total_ms}ms)
  confidence: low
  suggestions:
  - 考虑 AOT 编译优化
  - 检查是否有热点方法未被编译
  evidence_fields:
  - jit_events.data[0].total_ms
display:
  level: key
  layer: overview
  title: ART 诊断结果
```
