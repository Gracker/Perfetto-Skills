GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/binder_blocking_in_range.skill.yaml
Source SHA-256: 9e8a00b4d97ea3da1311a06c95ec77bc9e499ff4cd0237d28bebfbb1c720ee48
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# Binder 阻塞分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: binder_blocking_in_range
version: '1.0'
type: atomic
category: ipc
tier: B
```

## Metadata

```yaml
display_name: Binder 阻塞分析
description: 分析同步 Binder 调用中对端进程的响应延迟
icon: call_made
tags:
- binder
- ipc
- blocking
- atomic
```

## Prerequisites

```yaml
modules:
- android.binder
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns，可选)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns，可选)
- name: package
  type: string
  required: false
  description: 目标进程名（支持 GLOB 匹配）
```

## Query

Run [`../sql/binder_blocking_in_range/query.sql`](../sql/binder_blocking_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: Binder 同步阻塞
columns:
- name: server_process
  label: 对端进程
  type: string
- name: interface
  label: 接口
  type: string
- name: call_count
  label: 调用次数
  type: number
- name: total_block_ms
  label: 总阻塞时间
  type: duration
  format: duration_ms
- name: server_exec_ms
  label: 服务端执行
  type: duration
  format: duration_ms
- name: max_block_ms
  label: 最大阻塞
  type: duration
  format: duration_ms
- name: is_main_blocked
  label: 主线程被阻
  type: boolean
```
