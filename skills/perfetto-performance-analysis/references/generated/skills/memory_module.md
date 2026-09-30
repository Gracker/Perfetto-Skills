GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/hardware/memory_module.skill.yaml
Source SHA-256: c4d29f5ee21c06081cc03ddeefcc79718e488db294e4623000e124ce9c292f0b
# 内存分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: memory_module
version: '1.0'
type: composite
category: hardware
```

## Metadata

```yaml
display_name: 内存分析
description: 分析内存使用、LMK 事件、dmabuf 和内存压力
tags:
- hardware
- memory
- lmk
- dmabuf
- psi
- oom
```

## Prerequisites

```yaml
required_tables:
- counter
- counter_track
optional_tables:
- memory_snapshot
- android_lmk
```

## Inputs

```yaml
- name: package
  type: string
  required: false
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
layer: hardware
component: Memory
subsystems:
- lmk
- dmabuf
- psi
- page_cache
```

## Ordered execution

### 系统内存概览

- ID: `memory_overview`
- Type: `atomic`
- SQL: [`../sql/memory_module/memory_overview.sql`](../sql/memory_module/memory_overview.sql)

```yaml
id: memory_overview
type: atomic
display:
  level: key
  layer: overview
  title: 系统内存概览
save_as: memory_overview
synthesize:
  role: overview
  fields:
  - key: memory_type
    label: 内存类型
  - key: avg_mb
    label: 平均值
    format: '{{value}}MB'
  - key: max_mb
    label: 峰值
    format: '{{value}}MB'
```
### LMK 事件

- ID: `lmk_events`
- Type: `atomic`
- SQL: [`../sql/memory_module/lmk_events.sql`](../sql/memory_module/lmk_events.sql)

```yaml
id: lmk_events
type: atomic
display:
  level: detail
  layer: list
  title: LMK 事件
save_as: lmk_events
on_empty: 未检测到 LMK 事件
```
### dmabuf 内存使用

- ID: `dmabuf_usage`
- Type: `atomic`
- SQL: [`../sql/memory_module/dmabuf_usage.sql`](../sql/memory_module/dmabuf_usage.sql)

```yaml
id: dmabuf_usage
type: atomic
display:
  level: detail
  layer: overview
  title: dmabuf 内存
save_as: dmabuf_usage
```
### 内存压力指标

- ID: `memory_psi`
- Type: `atomic`
- SQL: [`../sql/memory_module/memory_psi.sql`](../sql/memory_module/memory_psi.sql)

```yaml
id: memory_psi
type: atomic
display:
  level: detail
  layer: overview
  title: 内存压力 (PSI)
save_as: memory_psi
```
### 进程内存

- ID: `process_memory`
- Type: `atomic`
- SQL: [`../sql/memory_module/process_memory.sql`](../sql/memory_module/process_memory.sql)

```yaml
id: process_memory
type: atomic
display:
  level: detail
  layer: list
  title: 进程内存使用
save_as: process_memory
optional: true
```
### 内存时间线

- ID: `memory_timeline`
- Type: `atomic`
- SQL: [`../sql/memory_module/memory_timeline.sql`](../sql/memory_module/memory_timeline.sql)

```yaml
id: memory_timeline
type: atomic
display:
  level: detail
  layer: list
  title: 内存时间线
save_as: memory_timeline
```
### 页面错误分析

- ID: `page_fault_analysis`
- Type: `atomic`
- SQL: [`../sql/memory_module/page_fault_analysis.sql`](../sql/memory_module/page_fault_analysis.sql)

```yaml
id: page_fault_analysis
type: atomic
display:
  level: detail
  layer: overview
  title: 页面错误
save_as: page_faults
optional: true
```
### 内存分配事件

- ID: `allocation_events`
- Type: `atomic`
- SQL: [`../sql/memory_module/allocation_events.sql`](../sql/memory_module/allocation_events.sql)

```yaml
id: allocation_events
type: atomic
display:
  level: detail
  layer: list
  title: 内存分配事件
save_as: allocation_events
```
### 内存诊断

- ID: `memory_diagnosis`
- Type: `diagnostic`

```yaml
id: memory_diagnosis
type: diagnostic
inputs:
- memory_overview
- lmk_events
- dmabuf_usage
- memory_psi
- process_memory
rules:
- condition: lmk_events.data.length > 0
  diagnosis: 检测到 ${lmk_events.data.length} 个 LMK 事件，系统内存压力大
  confidence: critical
  suggestions:
  - 检查内存泄漏
  - 减少后台进程内存使用
  - 优化缓存策略
  evidence_fields:
  - lmk_events.data.length
  - lmk_events.data[0]?.lmk_event
- condition: dmabuf_usage.data[0]?.growth_mb > 50
  diagnosis: dmabuf 内存增长 ${dmabuf_usage.data[0]?.growth_mb}MB，可能存在泄漏
  confidence: high
  suggestions:
  - 检查 Surface/Texture 是否正确释放
  - 检查 Bitmap 缓存策略
  - 使用 Android Studio Memory Profiler 分析
  evidence_fields:
  - dmabuf_usage.data[0]?.growth_mb
  - dmabuf_usage.data[0]?.max_mb
- condition: memory_psi.data[0]?.avg_value > 30
  diagnosis: '内存压力指标偏高: PSI 平均 ${memory_psi.data[0]?.avg_value}%'
  confidence: high
  suggestions:
  - 系统内存紧张，考虑释放缓存
  - 减少内存密集型操作
  - 检查是否有内存泄漏
  evidence_fields:
  - memory_psi.data[0]?.avg_value
  - memory_psi.data[0]?.max_value
- condition: memory_overview.data.find(m => m.memory_type.includes('Free'))?.min_mb < 100
  diagnosis: 可用内存最低降至 ${memory_overview.data.find(m => m.memory_type.includes('Free'))?.min_mb}MB
  confidence: high
  suggestions:
  - 系统内存极低，可能触发 LMK
  - 检查大内存消耗进程
  evidence_fields:
  - memory_overview.data[0]?.min_mb
- condition: process_memory.data[0]?.max_mb > 500
  diagnosis: 进程 ${process_memory.data[0]?.process_name} 内存峰值 ${process_memory.data[0]?.max_mb}MB
  confidence: medium
  suggestions:
  - 检查是否有大对象或集合
  - 考虑使用 LruCache
  - 分析堆内存组成
  evidence_fields:
  - process_memory.data[0]?.process_name
  - process_memory.data[0]?.max_mb
display:
  level: key
  layer: overview
  title: 内存诊断结果
```
