GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_process_state_residency.skill.yaml
Source SHA-256: 226abdc8bd617a35c5005014a5020538455aa88290a2d96fa911645bbb2387b1
# 进程状态驻留与切换

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_process_state_residency
version: '1.1'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: 进程状态驻留与切换
description: Framework 进程状态驻留、切换与启动/退出元数据；区分 OomAdjuster 状态变更原因和进程退出原因，用于 LMK、后台与内存压力分析
description_i18n:
  en: Framework process-state residency and transitions with recorded start and exit metadata; state-change reasons remain
    distinct from exit reasons.
icon: swap_vert
tags:
- memory
- lmk
- process_state
- background
- oom_adj
- framework
```

## Triggers

```yaml
keywords:
  zh:
  - 进程状态
  - process state
  - 后台进程
  - cached 进程
  - 进程优先级
  - 被杀前状态
  en:
  - process state
  - proc state
  - cached process
  - background process
  - process importance
patterns:
- .*(process state|proc state|进程状态).*
- .*(cached|后台).*(进程|process).*
```

## Prerequisites

```yaml
modules:
- android.process_state
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
  description: 目标进程名或包名（精确或 name:* 子进程）；留空返回全部有进程状态数据的进程
- name: upid
  type: integer
  required: false
  description: 可选的稳定进程身份
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)；驻留时长按窗口裁剪
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: max_rows
  type: integer
  required: false
  default: 200
  description: 状态切换序列最多返回的行数
```

## Ordered execution

### 进程状态能力检查

- ID: `process_state_capability`
- Type: `atomic`
- SQL: [`../sql/android_process_state_residency/process_state_capability.sql`](../sql/android_process_state_residency/process_state_capability.sql)

```yaml
id: process_state_capability
type: atomic
display:
  level: detail
  layer: overview
  title: 进程状态（android.process_state）能力
  columns:
  - name: runtime_has_process_state_table
    label: Runtime 有解析表
    type: number
  - name: runtime_has_process_state_module
    label: Runtime 有 stdlib 模块
    type: number
  - name: status
    label: 状态
    type: string
save_as: process_state_capability
```
### 进程状态数据检查

- ID: `process_state_data`
- Type: `atomic`
- SQL: [`../sql/android_process_state_residency/process_state_data.sql`](../sql/android_process_state_residency/process_state_data.sql)

```yaml
id: process_state_data
type: atomic
optional: true
condition: process_state_capability.data[0]?.status === 'runtime_supported'
display:
  level: detail
  layer: overview
  title: 进程状态数据
  columns:
  - name: state_event_count
    label: 状态事件数
    type: number
  - name: process_count
    label: 进程数
    type: number
  - name: matched_process_count
    label: 匹配目标的进程数
    type: number
  - name: status
    label: 状态
    type: string
sql_fragments:
- fragments/process_state_scoped_intervals.sql
save_as: process_state_data
```
### 进程状态驻留

- ID: `process_state_residency`
- Type: `atomic`
- SQL: [`../sql/android_process_state_residency/process_state_residency.sql`](../sql/android_process_state_residency/process_state_residency.sql)

```yaml
id: process_state_residency
type: atomic
optional: true
condition: process_state_data.data[0]?.status === 'available'
display:
  level: key
  layer: list
  title: 进程状态驻留（存活时间内，按窗口裁剪）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: state
    label: 状态
    type: string
  - name: state_rank
    label: 重要性序
    type: number
  - name: residency_ms
    label: 驻留时长
    type: duration
    format: duration_ms
    unit: ms
  - name: residency_pct
    label: 占存活时间
    type: percentage
    format: percentage
  - name: interval_count
    label: 进入次数
    type: number
  - name: first_entered_ts
    label: 首次进入
    type: timestamp
    unit: ns
sql_fragments:
- fragments/process_state_scoped_intervals.sql
save_as: process_state_residency
```
### 进程状态切换

- ID: `process_state_transitions`
- Type: `atomic`
- SQL: [`../sql/android_process_state_residency/process_state_transitions.sql`](../sql/android_process_state_residency/process_state_transitions.sql)

```yaml
id: process_state_transitions
type: atomic
optional: true
condition: process_state_data.data[0]?.status === 'available'
display:
  level: detail
  layer: list
  title: 进程状态切换序列
  title_i18n:
    en: Process State and Lifecycle Transitions
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: ts
    label: 切换时间
    type: timestamp
    unit: ns
  - name: prev_state
    label: 原状态
    type: string
  - name: state
    label: 新状态
    type: string
  - name: prev_state_ms
    label: 原状态停留
    type: duration
    format: duration_ms
    unit: ms
  - name: reason
    label: OomAdjuster 原因
    type: string
  - name: lifecycle
    label: 生命周期
    type: string
  - name: hosting_type
    label: 启动宿主类型
    label_i18n:
      en: Hosting Type
    type: string
  - name: hosting_name
    label: 启动宿主
    label_i18n:
      en: Hosting Name
    type: string
  - name: trigger_type
    label: 启动触发类型
    label_i18n:
      en: Start Trigger
    type: string
  - name: bind_application_delay_ms
    label: 绑定应用延迟
    label_i18n:
      en: Bind Application Delay
    type: duration
    format: duration_ms
    unit: ms
  - name: process_start_delay_ms
    label: 进程启动延迟
    label_i18n:
      en: Process Start Delay
    type: duration
    format: duration_ms
    unit: ms
  - name: exit_reason
    label: 退出原因
    label_i18n:
      en: Exit Reason
    type: string
  - name: exit_subreason
    label: 退出补充原因
    label_i18n:
      en: Exit Subreason
    type: string
sql_fragments:
- fragments/process_state_scoped_intervals.sql
save_as: process_state_transitions
```
### 最后观测状态

- ID: `process_state_last_observed`
- Type: `atomic`
- SQL: [`../sql/android_process_state_residency/process_state_last_observed.sql`](../sql/android_process_state_residency/process_state_last_observed.sql)

```yaml
id: process_state_last_observed
type: atomic
optional: true
condition: process_state_data.data[0]?.status === 'available'
display:
  level: key
  layer: list
  title: 每个进程最后一次观测到的状态
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: last_state
    label: 最后状态
    type: string
  - name: entered_ts
    label: 进入时间
    type: timestamp
    unit: ns
  - name: process_end_ts
    label: 进程结束时间
    type: timestamp
    unit: ns
  - name: lifecycle
    label: 生命周期
    type: string
sql_fragments:
- fragments/process_state_scoped_intervals.sql
save_as: process_state_last_observed
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: process_state_capability
  description: 'Runtime support: missing process-state parsing, module, or pinned lifecycle columns is reported explicitly;
    only runtime_supported runs the evidence queries'
- name: process_state_data
  description: Whether the trace carries android.process_state snapshot or state-change events, and whether any belong to
    the requested process
- name: process_state_residency
  description: Per process and framework state, time spent while alive within the window and its share of alive time; EXITED/NONEXISTENT
    markers are excluded
- name: process_state_transitions
  description: Ordered state changes and lifecycle markers. reason is the OomAdjuster state-change reason. NONEXISTENT carries
    recorded hosting/trigger and start delays; EXITED carries exit reasons at the process end, even when the reason event
    arrives later. Missing metadata stays null.
- name: process_state_last_observed
  description: Last alive state per process and whether the process ended, for comparing with LMK kills and oom_score_adj
```
