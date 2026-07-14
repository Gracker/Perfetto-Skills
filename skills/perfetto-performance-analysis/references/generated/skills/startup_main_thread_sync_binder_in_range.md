GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_main_thread_sync_binder_in_range.skill.yaml
Source SHA-256: 055c351e3fec64f581016e142b6784e2dc4e0847171726d986d757ff58f3b7e7
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# 启动主线程同步 Binder (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_main_thread_sync_binder_in_range
version: '1.0'
type: atomic
category: ipc
tier: B
```

## Metadata

```yaml
display_name: 启动主线程同步 Binder (区间)
description: 统计启动阶段主线程同步 Binder 调用耗时
icon: call
tags:
- startup
- main_thread
- binder
- ipc
- atomic
```

## Prerequisites

```yaml
modules:
- android.startup.startups
- android.binder
```

## Inputs

```yaml
- name: package
  type: string
  required: false
- name: startup_id
  type: integer
  required: false
- name: startup_type
  type: string
  required: false
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
- name: top_k
  type: integer
  required: false
```

## Query

Run [`../sql/startup_main_thread_sync_binder_in_range/query.sql`](../sql/startup_main_thread_sync_binder_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: overview
title: 主线程同步 Binder 调用
columns:
- name: server_process
  label: 服务进程
  type: string
- name: aidl_name
  label: AIDL 方法
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
- name: percent_of_startup
  label: 启动占比
  type: percentage
  format: percentage
```
