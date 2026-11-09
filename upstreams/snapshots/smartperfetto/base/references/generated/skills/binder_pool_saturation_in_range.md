GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/binder_pool_saturation_in_range.skill.yaml
Source SHA-256: d97947f0d5741f3e833349e9213a342b2eeb780815b6c1a53cba62ccf235a939
# Binder 线程池饱和

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: binder_pool_saturation_in_range
version: '1.1'
type: atomic
category: ipc
tier: B
```

## Metadata

```yaml
display_name: Binder 线程池饱和
display_name_i18n:
  en: Binder thread pool saturation
description: 窗口内目标进程及其主线程同步 Binder 对端的线程池：观测池大小、并发忙碌峰值、全部忙碌时长、进行中的 reply 与等待中的同步调用
description_i18n:
  en: 'Binder pools of the target process and its main thread''s sync binder servers in a window: observed pool size, peak
    concurrent busy threads, all-busy time, in-progress replies and waiting sync calls'
icon: call_made
tags:
- binder
- ipc
- thread_pool
- saturation
- atomic
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 窗口起点(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 窗口终点(ns)
- name: package
  type: string
  required: false
  description: 目标进程名（精确匹配，含 name:* 子进程）
- name: max_rows
  type: integer
  required: false
  default: 10
  description: 每个目标进程列出的最长进行中 reply / 等待调用数
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
```

## Ordered execution

### Binder 线程池饱和

- ID: `pool_saturation`
- Type: `atomic`
- SQL: [`../sql/binder_pool_saturation_in_range/pool_saturation.sql`](../sql/binder_pool_saturation_in_range/pool_saturation.sql)

```yaml
id: pool_saturation
type: atomic
display:
  level: key
  layer: overview
  title: Binder 线程池饱和
  title_i18n:
    en: Binder thread pool saturation
  row_semantics: per_entity
  columns:
  - name: window_start_ts
    label: window_start_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_end_ts
    label: window_end_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_dur_ns
    label: window_dur_ns
    type: duration
    unit: ns
  - name: upid
    label: upid
    type: number
  - name: pid
    label: pid
    type: number
  - name: process_name
    label: process_name
    type: string
  - name: target_role
    label: target_role
    type: string
  - name: pool_size
    label: pool_size
    type: number
    unit: count
  - name: pool_size_basis
    label: pool_size_basis
    type: string
  - name: named_binder_threads
    label: named_binder_threads
    type: number
    unit: count
  - name: inactive_binder_threads
    label: inactive_binder_threads
    type: number
    unit: count
  - name: reply_serving_threads
    label: reply_serving_threads
    type: number
    unit: count
  - name: busy_basis
    label: busy_basis
    type: string
  - name: peak_busy_threads
    label: peak_busy_threads
    type: number
    unit: count
    semantics: Most observed pool threads busy at the same time in the window. The pool is the active binder threads the trace
      shows, not the configured maximum.
  - name: saturated_ns
    label: saturated_ns
    type: duration
    unit: ns
    semantics: Time in the window while every observed pool thread was busy at once. An observation about the pool; it does
      not by itself prove a waiting client was delayed by queueing.
  - name: busy_thread_ns
    label: busy_thread_ns
    type: duration
    unit: ns
  - name: busy_slices
    label: busy_slices
    type: number
    unit: count
  - name: unfinished_busy_slices
    label: unfinished_busy_slices
    type: number
    unit: count
  - name: in_progress_replies
    label: in_progress_replies
    type: number
    unit: count
  - name: unfinished_replies
    label: unfinished_replies
    type: number
    unit: count
  - name: waiting_sync_calls
    label: waiting_sync_calls
    type: number
    unit: count
  - name: unreplied_sync_calls
    label: unreplied_sync_calls
    type: number
    unit: count
  - name: unreceived_sync_calls
    label: unreceived_sync_calls
    type: number
    unit: count
  - name: max_sync_wait_ns
    label: max_sync_wait_ns
    type: duration
    unit: ns
  - name: saturation_evidence
    label: saturation_evidence
    type: string
  - name: evidence_scope
    label: evidence_scope
    type: string
  - name: pool_evidence_status
    label: pool_evidence_status
    type: string
    hidden: true
process_scope:
  role: target
  binding: effective_target_processes
  limitations:
  - sync_binder_server 行是对端进程：由目标进程主线程在窗口内同步 Binder 调用的目的进程选出
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/system_target_threads.sql
- fragments/thread_role.sql
- fragments/binder_pool_activity.sql
save_as: pool_saturation
```
### 进行中的 Binder reply

- ID: `in_progress_replies`
- Type: `atomic`
- SQL: [`../sql/binder_pool_saturation_in_range/in_progress_replies.sql`](../sql/binder_pool_saturation_in_range/in_progress_replies.sql)

```yaml
id: in_progress_replies
type: atomic
display:
  level: detail
  layer: list
  title: 目标线程池中最长的进行中 reply
  title_i18n:
    en: Longest in-progress replies in the target pools
  columns:
  - name: upid
    label: upid
    type: number
  - name: process_name
    label: process_name
    type: string
  - name: target_role
    label: target_role
    type: string
  - name: server_utid
    label: server_utid
    type: number
  - name: server_tid
    label: server_tid
    type: number
  - name: server_thread_name
    label: server_thread_name
    type: string
  - name: reply_slice_id
    label: reply_slice_id
    type: number
    hidden: true
  - name: reply_ts
    label: reply_ts
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: reply_dur
    label: reply_dur
    type: duration
    unit: ns
  - name: is_unfinished
    label: is_unfinished
    type: number
  - name: busy_in_window_ns
    label: busy_in_window_ns
    type: duration
    unit: ns
  - name: client_utid
    label: client_utid
    type: number
  - name: client_tid
    label: client_tid
    type: number
  - name: client_thread_name
    label: client_thread_name
    type: string
  - name: client_upid
    label: client_upid
    type: number
  - name: client_process_name
    label: client_process_name
    type: string
process_scope:
  role: target
  binding: effective_target_processes
  limitations:
  - sync_binder_server 行是对端进程：由目标进程主线程在窗口内同步 Binder 调用的目的进程选出
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/system_target_threads.sql
- fragments/thread_role.sql
- fragments/binder_pool_activity.sql
```
### 等待中的同步 Binder 调用

- ID: `waiting_sync_calls`
- Type: `atomic`
- SQL: [`../sql/binder_pool_saturation_in_range/waiting_sync_calls.sql`](../sql/binder_pool_saturation_in_range/waiting_sync_calls.sql)

```yaml
id: waiting_sync_calls
type: atomic
display:
  level: detail
  layer: list
  title: 调用目标线程池的最长同步等待
  title_i18n:
    en: Longest synchronous calls waiting on the target pools
  columns:
  - name: server_upid
    label: server_upid
    type: number
  - name: server_process_name
    label: server_process_name
    type: string
  - name: target_role
    label: target_role
    type: string
  - name: call_slice_id
    label: call_slice_id
    type: number
    hidden: true
  - name: call_ts
    label: call_ts
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: call_dur
    label: call_dur
    type: duration
    unit: ns
  - name: is_unfinished
    label: is_unfinished
    type: number
  - name: waited_in_window_ns
    label: waited_in_window_ns
    type: duration
    unit: ns
  - name: call_state
    label: call_state
    type: string
  - name: client_utid
    label: client_utid
    type: number
  - name: client_tid
    label: client_tid
    type: number
  - name: client_thread_name
    label: client_thread_name
    type: string
  - name: client_upid
    label: client_upid
    type: number
  - name: client_process_name
    label: client_process_name
    type: string
  - name: client_is_main_thread
    label: client_is_main_thread
    type: number
  - name: server_utid
    label: server_utid
    type: number
  - name: server_tid
    label: server_tid
    type: number
  - name: server_thread_name
    label: server_thread_name
    type: string
  - name: reply_dur
    label: reply_dur
    type: duration
    unit: ns
process_scope:
  role: target
  binding: effective_target_processes
  limitations:
  - 调用方可以是任意进程；sync_binder_server 行是对端进程：由目标进程主线程在窗口内同步 Binder 调用的目的进程选出
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/system_target_threads.sql
- fragments/thread_role.sql
- fragments/binder_pool_activity.sql
```
## Output and evidence contract

```yaml
format: structured
```
