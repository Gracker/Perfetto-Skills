GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/page_fault_in_range.skill.yaml
Source SHA-256: 70c0fb8c89dddfe8a92611deb19c60d9126c1ed8c1e5c43e8d5639ce5f451a37
Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba
# 缺页异常分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: page_fault_in_range
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: 缺页异常分析
description: 分析 Page Fault 和内存回收对性能的影响
icon: memory
tags:
- memory
- page_fault
- reclaim
- atomic
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

Run [`../sql/page_fault_in_range/query.sql`](../sql/page_fault_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 缺页异常
columns:
- name: thread_name
  label: 线程
  type: string
- name: fault_type
  label: 类型
  type: string
- name: count
  label: 次数
  type: number
- name: total_ms
  label: 总耗时
  type: duration
  format: duration_ms
- name: max_ms
  label: 最大单次
  type: duration
  format: duration_ms
```
