GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/kernel/binder_module.skill.yaml
Source SHA-256: e374d828a42b45b2f0c2de0b02ca10fd40049073b3e8b52aedb4724592469f73
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
