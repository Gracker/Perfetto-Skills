GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/kernel/binder_module.skill.yaml
Source SHA-256: ac801a61aa0de9d819d8b84e2ccfcfb07d76ca816e88e5fde8c63d1832343e4a
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# Binder IPC 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: binder_module
version: '1.0'
type: composite
category: kernel
```

## Metadata

```yaml
display_name: Binder IPC 分析
description: 分析跨进程 Binder 调用、阻塞事务和调用延迟
tags:
- kernel
- binder
- ipc
- blocking
```

## Prerequisites

```yaml
modules:
- android.binder
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: Target package name
- name: tid
  type: number
  required: false
  description: Target thread ID
- name: caller
  type: string
  required: false
  description: Caller process name
- name: callee
  type: string
  required: false
  description: Callee process name
```

## Module contract

```yaml
layer: kernel
component: Binder
subsystems:
- transaction
- reply
- async
relatedModules:
- framework_ams
- framework_wms
- kernel_scheduler
```

## Dialogue guidance

```yaml
capabilities:
- id: binder_blocking_calls
  questionTemplate: What Binder calls blocked thread {tid}?
  requiredParams:
  - tid
  optionalParams:
  - start_ts
  - end_ts
  description: Find blocking Binder transactions for a thread
- id: binder_latency
  questionTemplate: What is the Binder latency between {caller} and {callee}?
  requiredParams:
  - caller
  - callee
  description: Analyze Binder transaction latency between processes
- id: heavy_binder_users
  questionTemplate: What are the heaviest Binder users for package {package}?
  requiredParams:
  - package
  description: Find processes making many Binder calls
findingsSchema:
- id: long_binder_transaction
  severity: critical
  titleTemplate: 'Long Binder transaction: {interface} took {dur_ms}ms'
  descriptionTemplate: Synchronous Binder call to {interface} blocked for {dur_ms}ms
  evidenceFields:
  - interface
  - dur_ms
  - caller_process
  - server_process
- id: excessive_binder_calls
  severity: warning
  titleTemplate: 'Excessive Binder calls: {call_count} calls to {interface}'
  descriptionTemplate: Process made {call_count} Binder calls totaling {total_ms}ms
  evidenceFields:
  - interface
  - call_count
  - total_ms
suggestionsSchema:
- id: check_server_process
  condition: server_process != package
  targetModule: scheduler_module
  questionTemplate: Why was server process {server_process} slow?
  paramsMapping:
    package: server_process
  priority: 1
- id: check_gc_during_binder
  condition: dur_ms > 10
  targetModule: art_module
  questionTemplate: Was there GC during Binder call at {ts}?
  paramsMapping:
    ts: start_ts
  priority: 2
```

## Ordered execution

### Binder 调用概览

- ID: `binder_summary`
- Type: `atomic`
- SQL: [`../sql/binder_module/binder_summary.sql`](../sql/binder_module/binder_summary.sql)

```yaml
id: binder_summary
type: atomic
display:
  level: detail
  layer: overview
  title: Binder 调用统计
save_as: binder_stats
synthesize: true
```
### 耗时同步调用

- ID: `long_sync_calls`
- Type: `atomic`
- SQL: [`../sql/binder_module/long_sync_calls.sql`](../sql/binder_module/long_sync_calls.sql)

```yaml
id: long_sync_calls
type: atomic
display:
  level: detail
  layer: list
  title: 耗时同步 Binder 调用
save_as: long_calls
synthesize: true
```
### 阻塞模式分析

- ID: `blocking_analysis`
- Type: `atomic`
- SQL: [`../sql/binder_module/blocking_analysis.sql`](../sql/binder_module/blocking_analysis.sql)

```yaml
id: blocking_analysis
type: atomic
display:
  level: detail
  layer: list
  title: Binder 阻塞分析
save_as: blocking_data
```
### Binder 诊断

- ID: `binder_diagnosis`
- Type: `diagnostic`

```yaml
id: binder_diagnosis
type: diagnostic
inputs:
- binder_stats
- long_calls
- blocking_data
rules:
- condition: long_calls.data[0]?.dur_ms > 16
  diagnosis: '发现长耗时 Binder 调用: ${long_calls.data[0]?.interface} (${long_calls.data[0]?.dur_ms}ms)，主线程被阻塞'
  confidence: high
  suggestions:
  - 考虑将该 Binder 调用移至后台线程
  - 检查服务端处理是否有性能问题
  evidence_fields:
  - long_calls.data[0].interface
  - long_calls.data[0].dur_ms
  - long_calls.data[0].server_process
- condition: binder_stats.data[0]?.sync_count > 20
  diagnosis: 'Binder 同步调用次数过多: ${binder_stats.data[0]?.interface} (${binder_stats.data[0]?.sync_count} 次)'
  confidence: medium
  suggestions:
  - 考虑批量处理减少调用次数
  - 使用异步 Binder 调用
  evidence_fields:
  - binder_stats.data[0].interface
  - binder_stats.data[0].sync_count
  - binder_stats.data[0].total_ms
- condition: blocking_data.data[0]?.total_block_ms > 50
  diagnosis: 'Binder 调用累计阻塞时间过长: ${blocking_data.data[0]?.server_process} (${blocking_data.data[0]?.total_block_ms}ms)'
  confidence: medium
  suggestions:
  - 检查服务端进程是否繁忙
  - 考虑缓存调用结果
  evidence_fields:
  - blocking_data.data[0].server_process
  - blocking_data.data[0].total_block_ms
display:
  level: key
  layer: overview
  title: Binder 诊断结果
```
