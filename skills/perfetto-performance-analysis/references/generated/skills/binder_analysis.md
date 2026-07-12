GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/binder_analysis.skill.yaml
Source SHA-256: d005054dab0e8c6ea08c377ca3407e935fb7134f30aa318211845cf32f3e2a0a
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# Binder 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: binder_analysis
version: '1.0'
type: composite
category: kernel
tier: S
```

## Metadata

```yaml
display_name: Binder 分析
description: 系统级 Binder 通信性能分析
icon: link
tags:
- binder
- ipc
- kernel
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - Binder
  - IPC
  - 跨进程
  - 服务调用
  - AIDL
  - 进程通信
  en:
  - binder
  - ipc
  - cross process
  - service call
  - aidl
  - transaction
patterns:
- .*[Bb]inder.*
- .*IPC.*
- .*跨进程.*
```

## Prerequisites

```yaml
required_tables:
- slice
modules:
- android.binder
- android.frames.timeline
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
- name: slow_binder_critical_ms
  type: number
  required: false
  default: 50
  description: 慢 Binder 严重阈值（ms）
- name: slow_binder_warning_ms
  type: number
  required: false
  default: 16
  description: 慢 Binder 警告阈值（ms）
- name: main_thread_txn_warning
  type: number
  required: false
  default: 50
  description: 主线程事务数告警阈值
- name: server_response_warning_ms
  type: number
  required: false
  default: 20
  description: 服务端响应告警阈值（ms）
```

## Ordered execution

### 检查 Binder 数据

- ID: `check_binder`
- Type: `atomic`
- SQL: [`../sql/binder_analysis/check_binder.sql`](../sql/binder_analysis/check_binder.sql)

```yaml
id: check_binder
type: atomic
optional: true
display:
  level: summary
  layer: overview
  title: 数据检查
  columns:
  - name: txn_count
    label: 事务数
    type: number
    format: compact
  - name: status
    label: 状态
    type: string
save_as: binder_check
```
### 选择目标进程

- ID: `get_process`
- Type: `atomic`
- SQL: [`../sql/binder_analysis/get_process.sql`](../sql/binder_analysis/get_process.sql)

```yaml
id: get_process
type: atomic
display:
  level: summary
  layer: overview
  title: 目标进程
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: txn_count
    label: 事务数
    type: number
    format: compact
  - name: total_client_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: max_dur_ms
    label: 最长耗时
    type: duration
    format: duration_ms
save_as: target_process
condition: binder_check.data[0]?.status === 'available'
```
### Binder 概览

- ID: `binder_overview`
- Type: `atomic`
- SQL: [`../sql/binder_analysis/binder_overview.sql`](../sql/binder_analysis/binder_overview.sql)

```yaml
id: binder_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: total_txns
    label: 总事务数
  - key: main_thread_txns
    label: 主线程调用
  - key: avg_dur_ms
    label: 平均耗时
    format: '{{value}} ms'
  - key: rating
    label: 评级
  insights:
  - condition: main_thread_slow_count > 5
    template: 主线程有 {{main_thread_slow_count}} 次慢 Binder 调用 (>16ms)
  - condition: max_dur_ms > 100
    template: 最长 Binder 调用 {{max_dur_ms}}ms，严重阻塞
display:
  level: key
  layer: overview
  title: Binder 调用概览
  columns:
  - name: total_txns
    label: 总事务数
    type: number
    format: compact
  - name: sync_txns
    label: 同步事务
    type: number
    format: compact
  - name: async_txns
    label: 异步事务
    type: number
    format: compact
  - name: main_thread_txns
    label: 主线程调用
    type: number
    format: compact
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
  - name: slow_calls_count
    label: 慢调用
    type: number
  - name: rating
    label: 评级
    type: string
save_as: binder_overview
condition: binder_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 发出的调用（按接口）

- ID: `outgoing_by_interface`
- Type: `atomic`
- SQL: [`../sql/binder_analysis/outgoing_by_interface.sql`](../sql/binder_analysis/outgoing_by_interface.sql)

```yaml
id: outgoing_by_interface
type: atomic
synthesize:
  role: list
  groupBy:
  - field: server_process
    title: 按服务进程分布
  fields:
  - key: aidl_interface
    label: AIDL 接口
  - key: call_count
    label: 调用次数
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms'
display:
  level: key
  layer: overview
  title: 发出的 Binder 调用（按接口）
  columns:
  - name: aidl_interface
    label: AIDL 接口
    type: string
  - name: server_process
    label: 服务进程
    type: string
  - name: call_count
    label: 调用次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
  - name: main_thread_count
    label: 主线程调用
    type: number
save_as: outgoing_by_interface
condition: binder_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 主线程同步 Binder

- ID: `main_thread_sync_binder`
- Type: `atomic`
- SQL: [`../sql/binder_analysis/main_thread_sync_binder.sql`](../sql/binder_analysis/main_thread_sync_binder.sql)

```yaml
id: main_thread_sync_binder
type: atomic
synthesize:
  role: list
  groupBy:
  - field: server_process
    title: 按服务进程分布
  - field: severity
    title: 按严重程度分布
  fields:
  - key: aidl_name
    label: AIDL 方法
  - key: dur_ms
    label: 耗时
    format: '{{value}} ms'
  - key: severity
    label: 严重程度
display:
  level: key
  layer: list
  title: 主线程同步 Binder 调用（可能导致掉帧）
  columns:
  - name: binder_ts
    label: 开始时间
    type: timestamp
    clickAction: navigate_timeline
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
  - name: server_process
    label: 服务进程
    type: string
  - name: aidl_name
    label: AIDL 方法
    type: string
  - name: aidl_interface
    label: AIDL 接口
    type: string
  - name: process_name
    label: 客户端
    type: string
  - name: severity
    label: 严重程度
    type: enum
save_as: main_thread_binder
condition: binder_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### Binder 阻塞分析

- ID: `binder_blocking_analysis`
- Type: `atomic`
- SQL: [`../sql/binder_analysis/binder_blocking_analysis.sql`](../sql/binder_analysis/binder_blocking_analysis.sql)

```yaml
id: binder_blocking_analysis
type: atomic
optional: true
display:
  level: key
  layer: list
  title: Binder 阻塞期间状态分析
  columns:
  - name: server_process
    label: 服务进程
    type: string
  - name: aidl_name
    label: AIDL 方法
    type: string
  - name: binder_dur_ms
    label: Binder 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: state
    label: 线程状态
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: state_dur_ms
    label: 状态耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: state_percent
    label: 状态占比
    type: percentage
    format: percentage
  - name: ts_str
    label: 时间
    type: timestamp
    clickAction: navigate_timeline
save_as: binder_blocking
condition: binder_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 服务端响应分析

- ID: `server_response_analysis`
- Type: `atomic`
- SQL: [`../sql/binder_analysis/server_response_analysis.sql`](../sql/binder_analysis/server_response_analysis.sql)

```yaml
id: server_response_analysis
type: atomic
display:
  level: detail
  layer: list
  title: 服务端处理时间分析
  columns:
  - name: server_process
    label: 服务进程
    type: string
  - name: aidl_interface
    label: AIDL 接口
    type: string
  - name: call_count
    label: 调用次数
    type: number
    format: compact
  - name: total_client_wait_ms
    label: 客户端总等待
    type: duration
    format: duration_ms
    unit: ms
  - name: total_server_process_ms
    label: 服务端总处理
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_server_dur_ms
    label: 服务端平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_server_dur_ms
    label: 服务端最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_transport_overhead_ms
    label: 平均传输开销
    type: duration
    format: duration_ms
    unit: ms
save_as: server_response
condition: binder_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### Binder 与帧关联

- ID: `binder_frame_correlation`
- Type: `atomic`
- SQL: [`../sql/binder_analysis/binder_frame_correlation.sql`](../sql/binder_analysis/binder_frame_correlation.sql)

```yaml
id: binder_frame_correlation
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: Binder 调用与帧渲染关联
  columns:
  - name: server_process
    label: 服务进程
    type: string
  - name: aidl_name
    label: AIDL 方法
    type: string
  - name: binder_dur_ms
    label: Binder 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: frame_id
    label: 帧 ID
    type: number
  - name: frame_dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: in_frame
    label: 帧内/帧外
    type: string
save_as: binder_frame
condition: binder_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 接收的调用

- ID: `incoming_calls`
- Type: `atomic`
- SQL: [`../sql/binder_analysis/incoming_calls.sql`](../sql/binder_analysis/incoming_calls.sql)

```yaml
id: incoming_calls
type: atomic
display:
  level: summary
  layer: list
  title: 接收的 Binder 调用
  columns:
  - name: client_process
    label: 客户端进程
    type: string
  - name: aidl_interface
    label: AIDL 接口
    type: string
  - name: call_count
    label: 调用次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
save_as: incoming_calls
condition: binder_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 慢 Binder 详细分析

- ID: `analyze_slow_binder`
- Type: `iterator`

```yaml
id: analyze_slow_binder
type: iterator
synthesize:
  role: clusters
  clusterBy: server_process
display:
  level: key
  layer: deep
  title: 慢 Binder 事务详细分析
source: main_thread_binder
item_skill: binder_detail
item_params:
  binder_ts: binder_ts
  binder_end_ts: binder_end_ts
  dur_ms: dur_ms
  server_process: server_process
  aidl_name: aidl_name
  process_name: process_name
  perfetto_start: perfetto_start
  perfetto_end: perfetto_end
max_items: 10
condition: main_thread_binder.data.length > 0
```
### Binder 诊断

- ID: `binder_diagnosis`
- Type: `diagnostic`

```yaml
id: binder_diagnosis
type: diagnostic
synthesize:
  role: conclusion
  fields:
  - key: diagnosis
    label: 诊断结论
  - key: severity
    label: 严重程度
  - key: confidence
    label: 置信度
  insights:
  - template: Binder 诊断：{{diagnosis}}
display:
  level: key
  layer: overview
  title: 问题诊断
inputs:
- binder_overview
- main_thread_binder
- binder_blocking
- server_response
rules:
- condition: binder_check?.data?.[0]?.status !== 'available'
  severity: warning
  diagnosis: unable_to_determine：缺少 android_binder_txns 或目标时段无 Binder 数据
  confidence: low
  suggestions:
  - '[Owner] Perf/Infra | [Priority] P0 | [Action] 采集包含 android.binder 模块的 trace 并覆盖问题时段'
  - '[Verify] 重新执行 binder_analysis，确认 binder_check.status=available'
  evidence_fields:
  - binder_check.data
- condition: main_thread_binder.data[0]?.dur_ms > (inputs?.slow_binder_critical_ms ?? 50)
  severity: critical
  diagnosis: 主线程存在严重慢 Binder 调用 (${main_thread_binder.data[0].dur_ms}ms)
  confidence: high
  suggestions:
  - '[Owner] App | [Priority] P0 | [Action] 将该 Binder 调用迁移到后台线程或异步化'
  - '[Owner] Service | [Priority] P0 | [Action] 优化服务 ${main_thread_binder.data[0].server_process} 响应链路'
  - '[Verify] 复测主线程 slow binder 次数和单次耗时'
  evidence_fields:
  - main_thread_binder.data
  - binder_overview.data
- condition: main_thread_binder.data[0]?.dur_ms > (inputs?.slow_binder_warning_ms ?? 16)
  severity: warning
  diagnosis: 主线程 Binder 调用超过一帧时间 (${main_thread_binder.data[0].dur_ms}ms)
  confidence: high
  suggestions:
  - '[Owner] App/Service | [Priority] P1 | [Action] 对主线程 Binder 做异步化并减少重调用'
  - '[Verify] 对比优化前后关键场景帧时长与 Binder P95'
  evidence_fields:
  - main_thread_binder.data
- condition: binder_overview.data[0]?.main_thread_txns > (inputs?.main_thread_txn_warning ?? 50)
  severity: warning
  diagnosis: 主线程发起 ${binder_overview.data[0].main_thread_txns} 次 Binder 调用
  confidence: medium
  suggestions:
  - '[Owner] App | [Priority] P1 | [Action] 合并调用、增加缓存并迁移非关键调用到后台线程'
  - '[Verify] 复测 main_thread_txns 和 slow_calls_count'
  evidence_fields:
  - binder_overview.data
- condition: server_response.data[0]?.avg_server_dur_ms > (inputs?.server_response_warning_ms ?? 20)
  severity: warning
  diagnosis: 服务端平均处理时间较长 (${server_response.data[0].avg_server_dur_ms}ms)
  confidence: medium
  suggestions:
  - '[Owner] Service | [Priority] P1 | [Action] 优化服务端热点接口与锁/IO路径'
  - '[Owner] App | [Priority] P2 | [Action] 结合缓存减少重复服务请求'
  - '[Verify] 复测 avg_server_dur_ms 与接口耗时分布'
  evidence_fields:
  - server_response.data
- condition: binder_blocking.data.find(b => b.state === 'D')?.state_percent > 50
  severity: warning
  diagnosis: Binder 阻塞期间存在大量 IO 等待
  confidence: medium
  suggestions:
  - '[Owner] Service | [Priority] P1 | [Action] 检查并下移阻塞 IO，避免同步链路卡住调用方'
  - '[Verify] 复测阻塞态占比与主线程阻塞时长'
  evidence_fields:
  - binder_blocking.data
```
## Output and evidence contract

```yaml
format: structured
```
