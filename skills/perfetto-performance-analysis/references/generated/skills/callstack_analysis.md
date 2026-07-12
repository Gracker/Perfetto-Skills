GENERATED FILE - DO NOT EDIT.
Source: backend/skills/deep/callstack_analysis.skill.yaml
Source SHA-256: 32723ee660e8cc822dc7b98136a23b15ba55fc88f77942c0ee0b658a654680f1
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# 调用栈分析 (Flamegraph)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: callstack_analysis
version: '3.0'
type: deep
category: deep_analysis
tier: S
```

## Metadata

```yaml
display_name: 调用栈分析 (Flamegraph)
description: 生成火焰图并分析热点函数
icon: local_fire_department
tags:
- flamegraph
- callstack
- cpu
- deep
level: 2
```

## Triggers

```yaml
keywords:
  zh:
  - 调用栈
  - 热点函数
  - CPU采样
  - 函数耗时
  - 火焰图
  - profiling
  en:
  - callstack
  - hotspot
  - cpu sampling
  - flame graph
  - profiling
  - perf
patterns:
- .*调用栈.*
- .*热点.*函数.*
- .*profil.*
- .*flame.*
```

## Prerequisites

```yaml
modules: null
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选）
- name: min_samples
  type: number
  required: false
  default: 10
  description: 最小采样数阈值
```

## Ordered execution

### 检查采样数据

- ID: `check_samples`
- Type: `atomic`
- SQL: [`../sql/callstack_analysis/check_samples.sql`](../sql/callstack_analysis/check_samples.sql)

```yaml
id: check_samples
type: atomic
display:
  level: summary
  layer: overview
  title: 采样数据概览
  columns:
  - name: total_samples
    label: 总采样数
    type: number
    format: compact
  - name: unique_callsites
    label: 唯一调用位置
    type: number
    format: compact
  - name: first_sample_ts
    label: 首次采样
    type: timestamp
    clickAction: navigate_timeline
  - name: last_sample_ts
    label: 末次采样
    type: timestamp
    clickAction: navigate_timeline
  - name: duration_sec
    label: 采样时长(秒)
    type: number
    format: compact
save_as: sample_stats
on_empty: 未找到 CPU 采样数据，请确保 trace 包含 simpleperf/perf 数据
```
### 热点函数 Top 20

- ID: `hot_functions`
- Type: `atomic`
- SQL: [`../sql/callstack_analysis/hot_functions.sql`](../sql/callstack_analysis/hot_functions.sql)

```yaml
id: hot_functions
type: atomic
optional: true
condition: sample_stats.data.length > 0 && sample_stats.data[0]?.total_samples > 0
display:
  level: detail
  layer: list
  title: 热点函数排行
  columns:
  - name: function_name
    label: 函数名
    type: string
  - name: module_name
    label: 模块
    type: string
  - name: sample_count
    label: 采样数
    type: number
    format: compact
  - name: percentage
    label: 占比
    type: percentage
    format: percentage
synthesize:
  role: list
  groupBy:
  - field: module_name
    title: 按模块分布
  fields:
  - key: function_name
    label: 函数名
  - key: percentage
    label: 占比
    format: '{{value}}%'
  insights:
  - condition: percentage > 10
    template: 热点函数 {{function_name}} 占 {{percentage}}%，是主要瓶颈
save_as: hot_functions
```
### 模块采样分布

- ID: `module_distribution`
- Type: `atomic`
- SQL: [`../sql/callstack_analysis/module_distribution.sql`](../sql/callstack_analysis/module_distribution.sql)

```yaml
id: module_distribution
type: atomic
optional: true
condition: sample_stats.data.length > 0 && sample_stats.data[0]?.total_samples > 0
display:
  level: detail
  layer: list
  title: 模块热度分布
  columns:
  - name: module_name
    label: 模块名
    type: string
  - name: module_type
    label: 模块类型
    type: string
  - name: sample_count
    label: 采样数
    type: number
    format: compact
  - name: percentage
    label: 占比
    type: percentage
    format: percentage
save_as: module_distribution
```
### 线程采样分布

- ID: `thread_hotspots`
- Type: `atomic`
- SQL: [`../sql/callstack_analysis/thread_hotspots.sql`](../sql/callstack_analysis/thread_hotspots.sql)

```yaml
id: thread_hotspots
type: atomic
optional: true
condition: sample_stats.data.length > 0 && sample_stats.data[0]?.total_samples > 0
display:
  level: detail
  layer: list
  title: 线程 CPU 采样分布
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: tid
    label: TID
    type: number
  - name: process_name
    label: 进程
    type: string
  - name: sample_count
    label: 采样数
    type: number
    format: compact
  - name: percentage
    label: 占比
    type: percentage
    format: percentage
save_as: thread_hotspots
```
### 热点函数调用者分析

- ID: `caller_analysis`
- Type: `atomic`
- SQL: [`../sql/callstack_analysis/caller_analysis.sql`](../sql/callstack_analysis/caller_analysis.sql)

```yaml
id: caller_analysis
type: atomic
optional: true
condition: (hot_functions?.data?.length || 0) > 0
display:
  level: detail
  layer: deep
  title: 调用路径追踪
  columns:
  - name: hot_function
    label: 热点函数
    type: string
  - name: call_depth
    label: 调用层级
    type: number
  - name: caller_name
    label: 调用者
    type: string
  - name: occurrence_count
    label: 出现次数
    type: number
    format: compact
save_as: caller_analysis
```
### 分析结论

- ID: `analysis_conclusion`
- Type: `atomic`
- SQL: [`../sql/callstack_analysis/analysis_conclusion.sql`](../sql/callstack_analysis/analysis_conclusion.sql)

```yaml
id: analysis_conclusion
type: atomic
optional: true
condition: sample_stats.data.length > 0 && sample_stats.data[0]?.total_samples > 0
display:
  level: summary
  layer: overview
  title: 调用栈分析结论
  columns:
  - name: total_samples
    label: 总采样数
    type: number
    format: compact
  - name: duration_sec
    label: 采样时长(秒)
    type: number
    format: compact
  - name: top_hotspots
    label: 热点函数
    type: string
  - name: dominant_module_type
    label: 主导模块
    type: string
  - name: suggestion
    label: 建议
    type: string
synthesize:
  role: conclusion
  fields:
  - key: top_hotspots
    label: 热点函数
  - key: dominant_module_type
    label: 主导模块
  - key: suggestion
    label: 建议
  insights:
  - template: 调用栈分析：{{dominant_module_type}} 为主，{{suggestion}}
```
