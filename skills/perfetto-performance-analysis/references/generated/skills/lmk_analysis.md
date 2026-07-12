GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/lmk_analysis.skill.yaml
Source SHA-256: 32494b794e68cb6976f27938f66c022758ebf4fcc0826baa535203c36b6aaceb
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# LMK 事件分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: lmk_analysis
version: '3.0'
type: composite
category: memory
tier: S
```

## Metadata

```yaml
display_name: LMK 事件分析
description: 分析 Low Memory Killer 事件
icon: close
tags:
- lmk
- memory
- kill
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - LMK
  - 低内存
  - 内存不足
  - 进程被杀
  - OOM
  - 内存压力
  - Low Memory Killer
  en:
  - lmk
  - low memory
  - out of memory
  - process kill
  - oom
  - memory pressure
patterns:
- .*LMK.*
- .*lmk.*
- .*低内存.*
- .*进程被杀.*
- .*out.*of.*memory.*
```

## Prerequisites

```yaml
required_tables:
- android_lmk_events
modules:
- android.memory.lmk
- linux.memory.general
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标应用包名（支持 GLOB），留空分析所有 LMK 事件
- name: oom_adj_threshold
  type: number
  required: false
  description: OOM adj 阈值，过滤低于此值的进程 (更重要的进程)
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
```

## Ordered execution

### 数据检测

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/lmk_analysis/data_check.sql`](../sql/lmk_analysis/data_check.sql)

```yaml
id: data_check
type: atomic
optional: true
display: false
save_as: data_check
```
### LMK 事件概览

- ID: `lmk_overview`
- Type: `atomic`
- SQL: [`../sql/lmk_analysis/lmk_overview.sql`](../sql/lmk_analysis/lmk_overview.sql)

```yaml
id: lmk_overview
type: atomic
condition: data_check.data[0]?.has_data === 1
synthesize:
  role: overview
  fields:
  - key: kill_reason
    label: 杀进程原因
  - key: kill_count
    label: 被杀次数
  - key: min_oom_adj
    label: 最低 OOM adj
  - key: killed_processes
    label: 被杀进程
  insights:
  - condition: kill_reason === 'LOW_MEM' && kill_count > 10
    template: 低内存杀进程 {{kill_count}} 次，系统内存严重不足
  - condition: kill_reason === 'LOW_SWAP_AND_THRASHING'
    template: Swap + Thrashing 导致杀进程，系统在频繁换页
  - condition: min_oom_adj <= 0
    template: 前台/系统进程被杀 (oom_adj={{min_oom_adj}})，严重影响用户体验
  - condition: min_oom_adj <= 200
    template: 可感知进程被杀 (oom_adj={{min_oom_adj}})，用户可能感知
display:
  level: summary
  layer: overview
  title: LMK 事件概览
  columns:
  - name: kill_reason
    label: 杀进程原因
    type: string
  - name: kill_count
    label: 次数
    type: number
    format: compact
  - name: killed_processes
    label: 被杀进程
    type: string
  - name: avg_oom_adj
    label: 平均 OOM adj
    type: number
    format: compact
  - name: min_oom_adj
    label: 最低 OOM adj
    type: number
    format: compact
save_as: lmk_overview
```
### LMK 事件时间线

- ID: `lmk_timeline`
- Type: `atomic`
- SQL: [`../sql/lmk_analysis/lmk_timeline.sql`](../sql/lmk_analysis/lmk_timeline.sql)

```yaml
id: lmk_timeline
type: atomic
condition: data_check.data[0]?.has_data === 1
display:
  level: detail
  layer: list
  title: LMK 事件时间线
  columns:
  - name: lmk_ts
    label: 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: process_name
    label: 进程
    type: string
  - name: pid
    label: PID
    type: number
    format: compact
  - name: oom_score_adj
    label: OOM adj
    type: number
    format: compact
  - name: kill_reason
    label: 原因
    type: string
  - name: process_priority
    label: 优先级
    type: string
save_as: lmk_timeline
```
### 高优先级进程被杀

- ID: `high_priority_kills`
- Type: `atomic`
- SQL: [`../sql/lmk_analysis/high_priority_kills.sql`](../sql/lmk_analysis/high_priority_kills.sql)

```yaml
id: high_priority_kills
type: atomic
condition: data_check.data[0]?.has_high_priority_kills === 1
synthesize:
  role: overview
  fields:
  - key: process_name
    label: 进程
  - key: kill_count
    label: 被杀次数
  - key: min_oom_adj
    label: 最低 OOM adj
  - key: kill_reasons
    label: 原因
  insights:
  - condition: min_oom_adj === 0
    template: 前台进程 {{process_name}} 被杀 {{kill_count}} 次，用户可能看到闪退
  - condition: min_oom_adj <= 100
    template: 可见进程 {{process_name}} 被杀 {{kill_count}} 次，用户可能感知
  - condition: kill_count > 3
    template: 进程 {{process_name}} 被频繁杀死 ({{kill_count}} 次)
display:
  level: detail
  layer: list
  title: 高优先级进程被杀（OOM adj <= 200）
  columns:
  - name: first_kill_ts
    label: 首次被杀
    type: timestamp
    clickAction: navigate_timeline
  - name: process_name
    label: 进程
    type: string
  - name: kill_count
    label: 次数
    type: number
    format: compact
  - name: min_oom_adj
    label: 最低 OOM adj
    type: number
    format: compact
  - name: kill_reasons
    label: 原因
    type: string
  - name: last_kill_ts
    label: 最后被杀
    type: timestamp
    clickAction: navigate_timeline
save_as: high_priority_kills
```
### LMK 时刻内存状态

- ID: `lmk_memory_context`
- Type: `atomic`
- SQL: [`../sql/lmk_analysis/lmk_memory_context.sql`](../sql/lmk_analysis/lmk_memory_context.sql)

```yaml
id: lmk_memory_context
type: atomic
condition: data_check.data[0]?.has_data === 1 && data_check.data[0]?.has_memory_counters === 1
display:
  level: detail
  layer: list
  title: LMK 时刻内存状态
  columns:
  - name: lmk_ts
    label: 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: process_name
    label: 进程
    type: string
  - name: kill_reason
    label: 原因
    type: string
  - name: free_mem_mb
    label: 空闲内存
    type: number
    format: compact
  - name: available_mem_mb
    label: 可用内存
    type: number
    format: compact
save_as: lmk_memory_context
```
### LMK 发生频率

- ID: `lmk_frequency`
- Type: `atomic`
- SQL: [`../sql/lmk_analysis/lmk_frequency.sql`](../sql/lmk_analysis/lmk_frequency.sql)

```yaml
id: lmk_frequency
type: atomic
condition: data_check.data[0]?.has_data === 1
display:
  level: detail
  layer: list
  title: LMK 发生频率（每秒）
  columns:
  - name: time_sec
    label: 时间 (秒)
    type: number
    format: compact
  - name: lmk_count
    label: LMK 次数
    type: number
    format: compact
  - name: killed_processes
    label: 被杀进程
    type: string
  - name: avg_oom_adj
    label: 平均 OOM adj
    type: number
    format: compact
save_as: lmk_frequency
```
### 进程重启分析

- ID: `process_restart_after_lmk`
- Type: `atomic`
- SQL: [`../sql/lmk_analysis/process_restart_after_lmk.sql`](../sql/lmk_analysis/process_restart_after_lmk.sql)

```yaml
id: process_restart_after_lmk
type: atomic
condition: data_check.data[0]?.has_data === 1
display:
  level: detail
  layer: list
  title: 被杀进程重启分析
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: restart_count
    label: 重启次数
    type: number
    format: compact
  - name: avg_restart_delay_ms
    label: 平均重启延迟
    type: duration
    format: duration_ms
    unit: ms
save_as: process_restart_after_lmk
```
### 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/lmk_analysis/root_cause_classification.sql`](../sql/lmk_analysis/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
condition: data_check.data[0]?.has_data === 1
synthesize:
  role: conclusion
  fields:
  - key: category
    label: 诊断类别
  - key: severity
    label: 严重程度
  - key: description
    label: 描述
  insights:
  - template: LMK 诊断：{{category}} - {{description}}
display:
  level: summary
  layer: diagnosis
  title: LMK 诊断
  columns:
  - name: category
    label: 诊断类别
    type: enum
  - name: severity
    label: 严重程度
    type: enum
  - name: description
    label: 描述
    type: string
  - name: evidence
    label: 依据
    type: string
save_as: root_cause
```
## Output and evidence contract

```yaml
format: structured
```
