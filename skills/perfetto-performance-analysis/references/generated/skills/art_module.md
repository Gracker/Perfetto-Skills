GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/framework/art_module.skill.yaml
Source SHA-256: e7d524de05ca91174a9bf283192a02d3dfab1324753b0b8ebfaaa259379d9e8a
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
