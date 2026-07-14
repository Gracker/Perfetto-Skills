GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/binder_in_range.skill.yaml
Source SHA-256: 3090864d8a14556995865f69ccf951cc39e5c1be1a8fca9fe2a2baf94d282e04
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# Binder 事务分析 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: binder_in_range
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: Binder 事务分析 (区间)
description: 分析指定时间范围内的 Binder 事务
icon: link
tags:
- binder
- transaction
- kernel
- atomic
```

## Prerequisites

```yaml
required_tables:
- slice
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
```

## Query

Run [`../sql/binder_in_range/query.sql`](../sql/binder_in_range/query.sql) with the declared inputs.

## Display metadata

```yaml
level: detail
format: table
columns:
- name: client_process
  label: 客户端
  type: string
- name: server_process
  label: 服务端
  type: string
- name: call_count
  label: 调用次数
  type: number
  format: compact
- name: total_client_ms
  label: 总耗时
  type: duration
  format: duration_ms
- name: max_delay_ms
  label: 最大延迟
  type: duration
  format: duration_ms
- name: avg_delay_ms
  label: 平均延迟
  type: duration
  format: duration_ms
- name: slow_calls
  label: 慢调用
  type: number
```
