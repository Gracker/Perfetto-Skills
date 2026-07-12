GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_main_thread_binder_blocking_in_range.skill.yaml
Source SHA-256: 0866842cce23d699030aca963d06aa7ea25eda19327dcc62360550adb2fa3395
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# 启动主线程 Binder 阻塞 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_main_thread_binder_blocking_in_range
version: '1.0'
type: atomic
category: ipc
tier: B
```

## Metadata

```yaml
display_name: 启动主线程 Binder 阻塞 (区间)
description: 分析启动阶段主线程同步 Binder 阻塞明细
icon: call_split
tags:
- startup
- main_thread
- binder
- blocking
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
- name: min_dur_ns
  type: integer
  required: false
- name: top_k
  type: integer
  required: false
```

## Query

Run [`../sql/startup_main_thread_binder_blocking_in_range/query.sql`](../sql/startup_main_thread_binder_blocking_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: list
title: 主线程 Binder 阻塞分析
columns:
- name: server_process
  label: 服务进程
  type: string
- name: aidl_name
  label: AIDL 方法
  type: string
- name: dur_ms
  label: 耗时
  type: duration
  format: duration_ms
- name: state
  label: 阻塞状态
  type: string
- name: blocked_function
  label: 阻塞函数
  type: string
  format: code
- name: ts_str
  label: 时间戳
  type: timestamp
  clickAction: navigate_timeline
- name: severity
  label: 严重程度
  type: enum
```
