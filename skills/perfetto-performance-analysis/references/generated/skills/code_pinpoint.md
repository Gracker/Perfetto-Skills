GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/code_pinpoint.skill.yaml
Source SHA-256: 2a96d49f363c3a2c12b64d46cf466a3457020d6b5ade488a7ac8360a28e35bad
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
# 代码定位线索

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: code_pinpoint
version: '1.0'
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
  - name: process_name
    label: Process
    type: string
  - name: thread_name
    label: Thread
    type: string
  - name: slice_name
    label: Slice
    type: string
  - name: dur_ms
    label: Duration
    type: duration
    unit: ms
```
### Native module / build-id 线索

- ID: `native_modules`
- Type: `atomic`
- SQL: [`../sql/code_pinpoint/native_modules.sql`](../sql/code_pinpoint/native_modules.sql)

```yaml
id: native_modules
type: atomic
display:
  level: debug
  layer: deep
  title: Native Module Hints
  columns:
  - name: module_name
    label: Module
    type: string
  - name: build_id
    label: Build ID
    type: string
  - name: frame_count
    label: Frames
    type: number
optional: true
```
