GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_binder_in_range.skill.yaml
Source SHA-256: 634089d0758acaec85224ca0440cd8e33c26da6dc537b93e0ee0f3e54d663f6c
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# 启动 Binder 总览 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_binder_in_range
version: '1.0'
type: atomic
category: ipc
tier: B
```

## Metadata

```yaml
display_name: 启动 Binder 总览 (区间)
description: 统计启动阶段 Binder 调用分布
icon: call_split
tags:
- startup
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

Run [`../sql/startup_binder_in_range/query.sql`](../sql/startup_binder_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: overview
title: 启动期间 Binder 调用
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
- name: main_thread_calls
  label: 主线程调用
  type: number
- name: percent_of_startup
  label: 启动占比
  type: percentage
  format: percentage
```
