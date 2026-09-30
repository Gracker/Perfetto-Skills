GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/app/third_party_module.skill.yaml
Source SHA-256: 187161c0bb28c5b2c3fc7793981fd519e399d3a17ee5a07d05ea9d64daf388b5
# 应用分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: third_party_module
version: '1.0'
type: composite
category: app
```

## Metadata

```yaml
display_name: 应用分析
description: 分析第三方应用性能、卡顿和资源使用
tags:
- app
- third_party
- jank
- performance
```

## Prerequisites

```yaml
modules:
- android.slices
```

## Inputs

```yaml
- name: package
  type: string
  required: true
  description: Target package name
- name: start_ts
  type: timestamp
  required: false
  description: Analysis start timestamp
- name: end_ts
  type: timestamp
  required: false
  description: Analysis end timestamp
```

## Module contract

```yaml
layer: app
component: ThirdParty
subsystems:
- main_thread
- render_thread
- background_threads
```

## Ordered execution

### 线程概览

- ID: `thread_overview`
- Type: `atomic`
- SQL: [`../sql/third_party_module/thread_overview.sql`](../sql/third_party_module/thread_overview.sql)

```yaml
id: thread_overview
type: atomic
display:
  level: key
  layer: overview
  title: 线程 CPU 使用
save_as: thread_overview
synthesize:
  role: overview
  fields:
  - key: thread_name
    label: 线程名
  - key: cpu_time_ms
    label: CPU 时间
    format: '{{value}}ms'
```
### 主线程状态分析

- ID: `main_thread_state`
- Type: `atomic`
- SQL: [`../sql/third_party_module/main_thread_state.sql`](../sql/third_party_module/main_thread_state.sql)

```yaml
id: main_thread_state
type: atomic
display:
  level: detail
  layer: overview
  title: 主线程状态分布
save_as: main_thread_state
synthesize: true
```
### 主线程耗时操作

- ID: `long_main_thread_slices`
- Type: `atomic`
- SQL: [`../sql/third_party_module/long_main_thread_slices.sql`](../sql/third_party_module/long_main_thread_slices.sql)

```yaml
id: long_main_thread_slices
type: atomic
display:
  level: detail
  layer: list
  title: 主线程耗时操作
save_as: long_slices
```
### RenderThread 分析

- ID: `render_thread_analysis`
- Type: `atomic`
- SQL: [`../sql/third_party_module/render_thread_analysis.sql`](../sql/third_party_module/render_thread_analysis.sql)

```yaml
id: render_thread_analysis
type: atomic
display:
  level: detail
  layer: overview
  title: RenderThread 状态
save_as: render_thread_state
```
### 应用诊断

- ID: `app_diagnosis`
- Type: `diagnostic`

```yaml
id: app_diagnosis
type: diagnostic
inputs:
- thread_overview
- main_thread_state
- long_slices
- render_thread_state
rules:
- condition: main_thread_state.data.find(s => s.state === 'Running')?.pct > 80
  diagnosis: 主线程 CPU 占用过高 (${main_thread_state.data.find(s => s.state === 'Running')?.pct}%)，可能导致 UI 响应慢
  confidence: high
  suggestions:
  - 将耗时操作移至后台线程
  - 使用协程或线程池
  evidence_fields:
  - main_thread_state.data[0].pct
  - main_thread_state.data[0].dur_ms
- condition: main_thread_state.data.find(s => s.state === 'R')?.pct > 10
  diagnosis: 主线程 Runnable 等待过长 (${main_thread_state.data.find(s => s.state === 'R')?.pct}%)，存在 CPU 竞争
  confidence: high
  suggestions:
  - 减少后台线程数量
  - 检查是否有后台进程占用 CPU
  evidence_fields:
  - main_thread_state.data.find(s => s.state === 'R')?.pct
- condition: long_slices.data[0]?.dur_ms > 16
  diagnosis: '发现耗时主线程任务: ${long_slices.data[0]?.task_name} (${long_slices.data[0]?.dur_ms}ms)'
  confidence: high
  suggestions:
  - 优化该任务或移至后台
  - 检查是否有同步 IO 或 Binder 调用
  evidence_fields:
  - long_slices.data[0].task_name
  - long_slices.data[0].dur_ms
- condition: thread_overview.data.length > 30
  diagnosis: 应用线程数过多 (${thread_overview.data.length} 个活跃线程)
  confidence: medium
  suggestions:
  - 合并相似功能线程
  - 使用线程池管理
  evidence_fields:
  - thread_overview.data.length
display:
  level: key
  layer: overview
  title: 应用诊断结果
```
