GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/anr_context_in_range.skill.yaml
Source SHA-256: 72ffcd16110748ddcd1ef5a9dc9ebaa508eac40ffac9571fe7a25a4eefe3000c
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# ANR 上下文提取

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: anr_context_in_range
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
optional: true
```

## Metadata

```yaml
display_name: ANR 上下文提取
description: 提取首个 ANR 事件的时间窗口参数，供后续分析步骤复用
icon: error
tags:
- anr
- context
- atomic
```

## Prerequisites

```yaml
modules:
- android.anrs
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
  description: 目标进程名
- name: package
  type: string
  required: false
  description: 应用包名（process_name 的别名）
- name: anr_type
  type: string
  required: false
  description: ANR 类型过滤
```

## Query

Run [`../sql/anr_context_in_range/query.sql`](../sql/anr_context_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: summary
layer: overview
title: ANR 上下文
columns:
- name: anr_ts
  label: ANR 时间
  type: timestamp
  clickAction: navigate_timeline
- name: timeout_ns
  label: 超时时长(ns)
  type: duration
  unit: ns
- name: timeout_ms
  label: 超时时长(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: timeout_source
  label: 超时来源
  type: string
- name: process_name
  label: 进程名
  type: string
- name: upid
  label: UPID
  type: number
- name: anr_type
  label: ANR 类型
  type: string
```
