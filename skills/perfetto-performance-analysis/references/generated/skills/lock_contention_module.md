GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
Source SHA-256: ca7ca4c40df11df499646b86be5c03ffef35d88535d034948b362516f1509118
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# 锁竞争分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: lock_contention_module
version: '1.0'
type: composite
category: kernel
```

## Metadata

```yaml
display_name: 锁竞争分析
description: 分析 Mutex/Monitor 竞争、死锁和优先级反转
tags:
- kernel
- lock
- mutex
- monitor
- contention
- synchronization
```

## Prerequisites

```yaml
required_tables:
- slice
- thread
- process
- thread_state
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
component: LockContention
subsystems:
- mutex
- futex
- monitor
- rwlock
relatedModules:
- kernel_scheduler
- framework_art
- app_third_party
```

## Dialogue guidance

```yaml
capabilities:
- id: lock_contention_overview
  questionTemplate: What lock contention exists for package {package}?
  requiredParams:
  - package
  description: Overview of lock contention issues
- id: monitor_contention
  questionTemplate: What Java monitor contention exists for package {package}?
  requiredParams:
  - package
  description: Analyze synchronized block contention
- id: mutex_wait_analysis
  questionTemplate: What mutex waits happened for thread {tid}?
  requiredParams:
  - tid
  optionalParams:
  - start_ts
  - end_ts
  description: Analyze specific thread's mutex waits
- id: lock_holder_analysis
  questionTemplate: Who is holding the lock that thread {tid} is waiting for?
  requiredParams:
  - tid
  description: Find lock holder causing contention
findingsSchema:
- id: high_lock_contention
  severity: critical
  titleTemplate: 'High lock contention: {wait_ms}ms total wait'
  descriptionTemplate: Thread spent {wait_ms}ms waiting for locks
  evidenceFields:
  - wait_ms
  - lock_name
  - waiting_thread
  - holder_thread
- id: monitor_contention_detected
  severity: warning
  titleTemplate: 'Monitor contention: {contention_count} waits on {monitor}'
  descriptionTemplate: Java synchronized block causing contention
  evidenceFields:
  - monitor
  - contention_count
  - total_wait_ms
  - avg_wait_ms
- id: potential_deadlock
  severity: critical
  titleTemplate: Potential deadlock between {thread1} and {thread2}
  descriptionTemplate: Circular lock dependency detected
  evidenceFields:
  - thread1
  - thread2
  - lock1
  - lock2
- id: priority_inversion
  severity: warning
  titleTemplate: 'Priority inversion: high priority thread waiting'
  descriptionTemplate: High priority thread {high_thread} waiting for low priority {low_thread}
  evidenceFields:
  - high_thread
  - low_thread
  - wait_ms
- id: long_lock_hold
  severity: warning
  titleTemplate: 'Long lock hold: {hold_ms}ms'
  descriptionTemplate: Lock held for {hold_ms}ms, causing others to wait
  evidenceFields:
  - hold_ms
  - holder_thread
  - lock_name
suggestionsSchema:
- id: check_thread_state
  condition: wait_ms > 50
  targetModule: scheduler_module
  questionTemplate: What is the lock holder thread doing?
  paramsMapping:
    tid: holder_tid
  priority: 1
- id: check_gc_holding_lock
  condition: holder_thread contains 'GC'
  targetModule: art_module
  questionTemplate: Is GC holding locks during collection?
  paramsMapping:
    package: package
  priority: 1
```

## Ordered execution

### 锁竞争概览

- ID: `lock_contention_overview`
- Type: `atomic`
- SQL: [`../sql/lock_contention_module/lock_contention_overview.sql`](../sql/lock_contention_module/lock_contention_overview.sql)

```yaml
id: lock_contention_overview
type: atomic
display:
  level: key
  layer: overview
  title: 锁竞争统计
save_as: lock_overview
synthesize:
  role: overview
  fields:
  - key: lock_event
    label: 锁事件
  - key: event_count
    label: 次数
  - key: total_wait_ms
    label: 总等待时间
    format: '{{value}}ms'
on_empty: 未检测到明显的锁竞争事件
```
### Monitor 竞争

- ID: `monitor_contention`
- Type: `atomic`
- SQL: [`../sql/lock_contention_module/monitor_contention.sql`](../sql/lock_contention_module/monitor_contention.sql)

```yaml
id: monitor_contention
type: atomic
display:
  level: detail
  layer: list
  title: Monitor 竞争事件
save_as: monitor_contention
```
### 阻塞线程分析

- ID: `blocked_threads`
- Type: `atomic`
- SQL: [`../sql/lock_contention_module/blocked_threads.sql`](../sql/lock_contention_module/blocked_threads.sql)

```yaml
id: blocked_threads
type: atomic
display:
  level: detail
  layer: list
  title: 线程阻塞统计
save_as: blocked_threads
synthesize: true
```
### 主线程锁等待

- ID: `main_thread_locks`
- Type: `atomic`
- SQL: [`../sql/lock_contention_module/main_thread_locks.sql`](../sql/lock_contention_module/main_thread_locks.sql)

```yaml
id: main_thread_locks
type: atomic
display:
  level: detail
  layer: list
  title: 主线程锁等待
save_as: main_thread_locks
```
### Binder 线程锁等待

- ID: `binder_thread_locks`
- Type: `atomic`
- SQL: [`../sql/lock_contention_module/binder_thread_locks.sql`](../sql/lock_contention_module/binder_thread_locks.sql)

```yaml
id: binder_thread_locks
type: atomic
display:
  level: detail
  layer: list
  title: Binder 线程锁等待
save_as: binder_thread_locks
```
### 长时间锁持有

- ID: `long_lock_holds`
- Type: `atomic`
- SQL: [`../sql/lock_contention_module/long_lock_holds.sql`](../sql/lock_contention_module/long_lock_holds.sql)

```yaml
id: long_lock_holds
type: atomic
display:
  level: detail
  layer: list
  title: 长时间锁持有
save_as: long_lock_holds
optional: true
```
### 线程竞争关系

- ID: `thread_contention_pairs`
- Type: `atomic`
- SQL: [`../sql/lock_contention_module/thread_contention_pairs.sql`](../sql/lock_contention_module/thread_contention_pairs.sql)

```yaml
id: thread_contention_pairs
type: atomic
display:
  level: detail
  layer: list
  title: 线程阻塞比例
save_as: thread_contention_pairs
```
### 锁竞争诊断

- ID: `lock_diagnosis`
- Type: `diagnostic`

```yaml
id: lock_diagnosis
type: diagnostic
inputs:
- lock_overview
- monitor_contention
- blocked_threads
- main_thread_locks
rules:
- condition: main_thread_locks.data.length > 0
  diagnosis: 主线程检测到 ${main_thread_locks.data.length} 次锁等待，最长 ${main_thread_locks.data[0]?.wait_ms}ms
  confidence: critical
  suggestions:
  - 主线程不应等待锁
  - 将竞争资源的访问移至后台线程
  - 使用无锁数据结构
  evidence_fields:
  - main_thread_locks.data.length
  - main_thread_locks.data[0]?.lock_event
  - main_thread_locks.data[0]?.wait_ms
- condition: lock_overview.data[0]?.total_wait_ms > 100
  diagnosis: 锁竞争总等待时间 ${lock_overview.data[0]?.total_wait_ms}ms
  confidence: high
  suggestions:
  - 减少临界区代码
  - 考虑使用细粒度锁
  - 使用读写锁分离
  evidence_fields:
  - lock_overview.data[0]?.lock_event
  - lock_overview.data[0]?.total_wait_ms
- condition: monitor_contention.data[0]?.wait_ms > 10
  diagnosis: 'Java Monitor 竞争: ${monitor_contention.data[0]?.monitor_event} 等待 ${monitor_contention.data[0]?.wait_ms}ms'
  confidence: high
  suggestions:
  - 检查 synchronized 块的必要性
  - 考虑使用 ReentrantLock 提供更好的控制
  - 缩小 synchronized 范围
  evidence_fields:
  - monitor_contention.data[0]?.monitor_event
  - monitor_contention.data[0]?.wait_ms
  - monitor_contention.data[0]?.waiting_thread
- condition: blocked_threads.data.filter(t => t.state === 'D').length > 3
  diagnosis: 多个线程处于不可中断阻塞状态，可能存在 I/O 或锁等待
  confidence: medium
  suggestions:
  - 检查是否有 I/O 阻塞
  - 检查是否有内核锁竞争
  evidence_fields:
  - blocked_threads.data.filter(t => t.state === 'D').length
- condition: thread_contention_pairs.data[0]?.blocked_pct > 30
  diagnosis: 线程 ${thread_contention_pairs.data[0]?.thread_name} 阻塞时间占比 ${thread_contention_pairs.data[0]?.blocked_pct}%
  confidence: medium
  suggestions:
  - 该线程大部分时间在等待
  - 分析其等待的资源
  evidence_fields:
  - thread_contention_pairs.data[0]?.thread_name
  - thread_contention_pairs.data[0]?.blocked_pct
display:
  level: key
  layer: overview
  title: 锁竞争诊断结果
```
