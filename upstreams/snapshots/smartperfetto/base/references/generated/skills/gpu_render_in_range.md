GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/gpu_render_in_range.skill.yaml
Source SHA-256: 1c142b8dbc84b47518922a8a37b43c85c1e3e887ad5bfc61179c1710dce9c286
Source commit: 67a2eec9888ed577e66284c709f4987a617bd286
# GPU 渲染分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gpu_render_in_range
version: '1.0'
type: atomic
category: gpu
tier: B
```

## Metadata

```yaml
display_name: GPU 渲染分析
description: 分析 GPU 渲染耗时和 Fence 等待
icon: memory
tags:
- gpu
- render
- fence
- atomic
pipeline_aware: true
pipeline_aware_note: 'GPU 工作来源不同：标准 RenderThread；Flutter raster；Game (Vulkan vs GLES)；

  Camera ISP；Video decoder。未来按 pipeline_id 切换 GPU 来源识别 SQL。

  '
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

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
```

## Query

Run [`../sql/gpu_render_in_range/query.sql`](../sql/gpu_render_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: GPU 渲染
columns:
- name: operation
  label: 操作类型
  type: string
- name: count
  label: 次数
  type: number
- name: total_ms
  label: 总耗时
  type: duration
  format: duration_ms
- name: max_ms
  label: 最大耗时
  type: duration
  format: duration_ms
- name: avg_ms
  label: 平均耗时
  type: duration
  format: duration_ms
```
