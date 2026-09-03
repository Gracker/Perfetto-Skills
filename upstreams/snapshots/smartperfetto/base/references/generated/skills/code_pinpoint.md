GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/code_pinpoint.skill.yaml
Source SHA-256: c2560c8a63a870cc090ef0176632c2c572fd52bb4301adaa16342cbb651204ce
Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f
# 代码定位线索

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: code_pinpoint
version: '1.1'
type: composite
tier: S
```

## Metadata

```yaml
display_name: 代码定位线索
description: 从 trace 中提取可用于 codebase-aware resolve_symbol / lookup_source 的线程、slice、module 和 symbol 线索
icon: code
tags:
- codebase
- symbol
- source
- root_cause
```

## Triggers

```yaml
keywords:
  zh:
  - 代码
  - 源码
  - 函数
  - 符号
  - patch
  - 修复建议
  - file line
  en:
  - code
  - source
  - symbol
  - function
  - patch
  - file line
```

## Prerequisites

```yaml
modules:
- slices.with_context
- android.process_metadata
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名或进程名（可选）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
- process_name
rewriteTo: recommended_process_name_param
```

## Ordered execution

### 代码定位候选 slice

- ID: `hot_slices`
- Type: `atomic`
- SQL: [`../sql/code_pinpoint/hot_slices.sql`](../sql/code_pinpoint/hot_slices.sql)

```yaml
id: hot_slices
type: atomic
display:
  level: detail
  layer: list
  title: Code Pinpoint Candidates
  columns:
  - name: slice_id
    label: Slice ID
    type: number
  - name: ts
    label: Timestamp
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur_ms
    label: Duration
    type: duration
    unit: ms
  - name: upid
    label: UPID
    type: number
  - name: utid
    label: UTID
    type: number
  - name: process_name
    label: Process
    type: string
  - name: thread_name
    label: Thread
    type: string
  - name: slice_name
    label: Slice
    type: string
  - name: anchor_kind
    label: Anchor Kind
    type: string
  - name: source_query_hint
    label: Source Query Hint
    type: string
synthesize:
  role: list
  fields:
  - key: slice_name
    label: Trace 锚点
  - key: anchor_kind
    label: 锚点类型
  - key: source_query_hint
    label: 源码检索词
```
### Native symbol / module / build-id 线索

- ID: `native_symbols`
- Type: `atomic`
- SQL: [`../sql/code_pinpoint/native_symbols.sql`](../sql/code_pinpoint/native_symbols.sql)

```yaml
id: native_symbols
type: atomic
display:
  level: debug
  layer: deep
  title: Native Symbol Anchors
  columns:
  - name: function_name
    label: Function
    type: string
  - name: module_name
    label: Module
    type: string
  - name: build_id
    label: Build ID
    type: string
  - name: sample_count
    label: Samples
    type: number
    format: compact
synthesize:
  role: list
  fields:
  - key: function_name
    label: 函数名
  - key: module_name
    label: 模块
  - key: build_id
    label: Build ID
  - key: sample_count
    label: 采样数
optional: true
on_empty: 'no_symbol_data: trace 中没有符合当前进程与时间窗的 CPU profiling 符号数据'
```
