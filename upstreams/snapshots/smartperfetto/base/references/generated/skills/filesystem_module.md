GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
Source SHA-256: e2ba372b872ef978f342ad67351e9294edd801ecae1c716d110212a8bc88cd94
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 文件系统 I/O 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: filesystem_module
version: '1.0'
type: composite
category: kernel
```

## Metadata

```yaml
display_name: 文件系统 I/O 分析
description: 分析块 I/O、文件操作、数据库访问和 I/O 延迟
tags:
- kernel
- filesystem
- io
- block
- database
- sqlite
```

## Prerequisites

```yaml
required_tables:
- slice
- thread
- process
- thread_state
optional_tables:
- io_uring_events
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
layer: kernel
component: FileSystem
subsystems:
- block_io
- file_operations
- database
- shared_preferences
relatedModules:
- kernel_scheduler
- framework_ams
- app_third_party
```

## Dialogue guidance

```yaml
capabilities:
- id: io_during_startup
  questionTemplate: What IO operations delayed startup for package {package}?
  requiredParams:
  - package
  description: Analyze IO operations during app startup
- id: main_thread_io
  questionTemplate: What IO operations happened on main thread for package {package}?
  requiredParams:
  - package
  description: Find synchronous IO on main thread
- id: database_operations
  questionTemplate: What database operations happened for package {package}?
  requiredParams:
  - package
  optionalParams:
  - start_ts
  - end_ts
  description: Analyze SQLite/Room database operations
- id: io_latency_analysis
  questionTemplate: What is the IO latency distribution for package {package}?
  requiredParams:
  - package
  description: Analyze IO latency patterns
- id: block_io_summary
  questionTemplate: What is the block IO activity during {start_ts} to {end_ts}?
  requiredParams:
  - start_ts
  - end_ts
  description: Summarize block IO activity in time range
findingsSchema:
- id: main_thread_io
  severity: critical
  titleTemplate: 'Main thread IO: {io_type} took {dur_ms}ms'
  descriptionTemplate: Synchronous IO on main thread blocked UI for {dur_ms}ms
  evidenceFields:
  - io_type
  - dur_ms
  - file_path
  - thread_name
- id: slow_database_query
  severity: warning
  titleTemplate: 'Slow database query: {query_ms}ms'
  descriptionTemplate: Database query took {query_ms}ms, consider optimization
  evidenceFields:
  - query_ms
  - table_name
  - operation_type
- id: excessive_io_operations
  severity: warning
  titleTemplate: 'Excessive IO: {io_count} operations totaling {total_ms}ms'
  descriptionTemplate: High number of IO operations may cause performance issues
  evidenceFields:
  - io_count
  - total_ms
  - avg_ms
- id: io_wait_causing_delay
  severity: critical
  titleTemplate: 'IO wait causing delay: {wait_ms}ms'
  descriptionTemplate: Thread spent {wait_ms}ms waiting for IO operations
  evidenceFields:
  - wait_ms
  - thread_name
  - io_type
suggestionsSchema:
- id: check_scheduler_during_io
  condition: io_wait_ms > 50
  targetModule: scheduler_module
  questionTemplate: Why was thread blocked during IO at {ts}?
  paramsMapping:
    ts: io_start_ts
  priority: 1
- id: check_memory_pressure
  condition: io_type == 'page_fault'
  targetModule: memory_module
  questionTemplate: Is memory pressure causing page faults?
  paramsMapping: {}
  priority: 2
```

## Ordered execution

### I/O 操作概览

- ID: `io_overview`
- Type: `atomic`
- SQL: [`../sql/filesystem_module/io_overview.sql`](../sql/filesystem_module/io_overview.sql)

```yaml
id: io_overview
type: atomic
display:
  level: key
  layer: overview
  title: I/O 操作统计
save_as: io_overview
synthesize:
  role: overview
  fields:
  - key: io_type
    label: I/O 类型
  - key: operation_count
    label: 操作次数
  - key: total_ms
    label: 总耗时
    format: '{{value}}ms'
```
### 主线程 I/O

- ID: `main_thread_io`
- Type: `atomic`
- SQL: [`../sql/filesystem_module/main_thread_io.sql`](../sql/filesystem_module/main_thread_io.sql)

```yaml
id: main_thread_io
type: atomic
display:
  level: detail
  layer: list
  title: 主线程 I/O 操作
save_as: main_thread_io
synthesize: true
```
### 数据库操作

- ID: `database_operations`
- Type: `atomic`
- SQL: [`../sql/filesystem_module/database_operations.sql`](../sql/filesystem_module/database_operations.sql)

```yaml
id: database_operations
type: atomic
display:
  level: detail
  layer: list
  title: 数据库操作
save_as: db_operations
```
### SharedPreferences 操作

- ID: `shared_prefs_operations`
- Type: `atomic`
- SQL: [`../sql/filesystem_module/shared_prefs_operations.sql`](../sql/filesystem_module/shared_prefs_operations.sql)

```yaml
id: shared_prefs_operations
type: atomic
display:
  level: detail
  layer: list
  title: SharedPreferences 操作
save_as: sp_operations
```
### I/O 等待状态

- ID: `io_wait_state`
- Type: `atomic`
- SQL: [`../sql/filesystem_module/io_wait_state.sql`](../sql/filesystem_module/io_wait_state.sql)

```yaml
id: io_wait_state
type: atomic
display:
  level: detail
  layer: list
  title: 线程 I/O 等待
save_as: io_wait_state
synthesize: true
```
### 疑似慢 I/O 命名切片

- ID: `slow_io_operations`
- Type: `atomic`
- SQL: [`../sql/filesystem_module/slow_io_operations.sql`](../sql/filesystem_module/slow_io_operations.sql)

```yaml
id: slow_io_operations
type: atomic
display:
  level: detail
  layer: list
  title: 疑似慢 I/O 命名切片 (>10ms)
save_as: slow_io
```
### I/O 诊断

- ID: `io_diagnosis`
- Type: `diagnostic`

```yaml
id: io_diagnosis
type: diagnostic
inputs:
- io_overview
- main_thread_io
- db_operations
- io_wait_state
- slow_io
rules:
- condition: main_thread_io.data.length > 0
  diagnosis: 主线程观测到 ${main_thread_io.data.length} 个疑似 I/O 命名切片，最长 ${main_thread_io.data[0]?.dur_ms}ms；切片名本身不能证明底层存储阻塞
  confidence: medium
  suggestions:
  - 将 I/O 操作移至后台线程
  - 使用 Kotlin 协程或 RxJava 异步处理
  - 考虑使用 Room 的 suspend 函数
  evidence_fields:
  - main_thread_io.data.length
  - main_thread_io.data[0]?.dur_ms
  - main_thread_io.data[0]?.io_operation
- condition: db_operations.data.filter(op => op.thread_type === 'main_thread').length > 5
  diagnosis: 主线程观测到多次疑似数据库命名切片；需结合 SQL/atrace 埋点确认具体 Room/SQLite 调用
  confidence: medium
  suggestions:
  - 数据库查询应在后台线程执行
  - 使用 Room 的 @Query 配合 LiveData/Flow
  - 考虑批量处理减少查询次数
  evidence_fields:
  - db_operations.data[0]?.db_operation
  - db_operations.data[0]?.dur_ms
- condition: io_wait_state.data[0]?.io_wait_ms > 50
  diagnosis: '线程 I/O 等待时间过长: ${io_wait_state.data[0]?.thread_name} 等待 ${io_wait_state.data[0]?.io_wait_ms}ms'
  confidence: high
  suggestions:
  - 检查存储设备性能
  - 减少同步 I/O 操作
  - 考虑使用缓存
  evidence_fields:
  - io_wait_state.data[0]?.thread_name
  - io_wait_state.data[0]?.io_wait_ms
- condition: slow_io.data.filter(op => op.severity === 'CRITICAL').length > 0
  diagnosis: '主线程观测到疑似慢 I/O 命名切片: ${slow_io.data.filter(op => op.severity === ''CRITICAL'')[0]?.operation}；需结合线程状态或明确 I/O
    埋点确认'
  confidence: medium
  suggestions:
  - 确认该切片是否代表真实同步文件 I/O，再决定是否移至后台
  - 若它持续阻塞主线程并超过响应阈值，再结合调度状态评估 ANR 风险
  evidence_fields:
  - slow_io.data[0]?.operation
  - slow_io.data[0]?.dur_ms
- condition: io_overview.data[0]?.total_ms > 500
  diagnosis: I/O 操作总耗时 ${io_overview.data[0]?.total_ms}ms，占用大量时间
  confidence: medium
  suggestions:
  - 优化 I/O 访问模式
  - 使用批量读写减少系统调用
  - 考虑内存缓存
  evidence_fields:
  - io_overview.data[0]?.io_type
  - io_overview.data[0]?.total_ms
display:
  level: key
  layer: overview
  title: I/O 诊断结果
```
