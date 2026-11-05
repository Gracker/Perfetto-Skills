GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_job_scheduler_events.skill.yaml
Source SHA-256: aa6721a92d941b2fca0139aeba55e46532db1d83720306e4d47b18ac850346bd
# JobScheduler 事件

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_job_scheduler_events
version: '1.1'
type: atomic
category: background
tier: B
```

## Metadata

```yaml
display_name: JobScheduler 事件
display_name_i18n:
  en: JobScheduler Events and Wait Reasons
description: 保留 ATrace 任务执行序列，补充 track-event 已完成任务的等待原因；按包名/UID 归属，不证明具体 UPID。等待原因可能重叠，不可相加为排队总时长；取消或未完成任务不在等待汇总内。
description_i18n:
  en: ATrace job execution and reported wait reasons for completed track-event jobs. Package/UID attribution is not exact
    UPID attribution. Reasons may overlap and cannot be added into total queue time; cancelled or unfinished jobs are excluded
    from the wait summary.
icon: schedule
tags:
- job_scheduler
- background
- lifecycle
- atomic
```

## Prerequisites

```yaml
modules:
- android.job_scheduler
- android.job_scheduler_states_track_events
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标包名（可选，精确匹配，含 name:* 子进程）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)：ATrace 按执行区间相交，等待汇总按任务启动时间筛选；上报等待时长不按窗口裁剪
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
```

## Ordered execution

### Job 事件列表

- ID: `job_events`
- Type: `atomic`
- SQL: [`../sql/android_job_scheduler_events/job_events.sql`](../sql/android_job_scheduler_events/job_events.sql)

```yaml
id: job_events
type: atomic
display:
  level: detail
  layer: list
  title: JobScheduler 任务
  columns:
  - name: ts
    label: 时间
    type: timestamp
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
  - name: job_name
    label: 任务名
    type: string
  - name: package_name
    label: 包名
    type: string
  - name: uid
    label: UID
    type: number
```
### 等待原因能力检查

- ID: `pending_reason_capability`
- Type: `atomic`
- SQL: [`../sql/android_job_scheduler_events/pending_reason_capability.sql`](../sql/android_job_scheduler_events/pending_reason_capability.sql)

```yaml
id: pending_reason_capability
type: atomic
display:
  level: detail
  layer: overview
  title: JobScheduler track-event 等待原因能力
  title_i18n:
    en: JobScheduler track-event wait-reason support
  columns:
  - name: status
    label: Runtime 状态
    label_i18n:
      en: Runtime status
    type: string
save_as: pending_reason_capability
```
### 已完成任务等待原因数据检查

- ID: `pending_reason_data`
- Type: `atomic`
- SQL: [`../sql/android_job_scheduler_events/pending_reason_data.sql`](../sql/android_job_scheduler_events/pending_reason_data.sql)

```yaml
id: pending_reason_data
type: atomic
optional: true
condition: pending_reason_capability.data[0]?.status === 'runtime_supported'
display:
  level: detail
  layer: overview
  title: 窗口内启动且已完成的任务：等待原因覆盖
  title_i18n:
    en: Wait-reason coverage for completed jobs started in the window
  columns:
  - name: completed_job_count
    label: 带等待原因的已完成任务数
    label_i18n:
      en: Completed jobs with wait reasons
    type: number
  - name: reason_entry_count
    label: 等待原因条目数
    label_i18n:
      en: Wait-reason entries
    type: number
  - name: missing_duration_count
    label: 缺少等待时长的条目数
    label_i18n:
      en: Entries missing a duration
    type: number
  - name: status
    label: 数据状态
    label_i18n:
      en: Data status
    type: string
save_as: pending_reason_data
```
### 已完成任务等待原因汇总

- ID: `pending_reason_summary`
- Type: `atomic`
- SQL: [`../sql/android_job_scheduler_events/pending_reason_summary.sql`](../sql/android_job_scheduler_events/pending_reason_summary.sql)

```yaml
id: pending_reason_summary
type: atomic
optional: true
condition: pending_reason_data.data[0]?.status === 'available'
display:
  level: key
  layer: list
  title: 已完成任务上报的等待原因（非排队总时长；取消/未完成任务不含）
  title_i18n:
    en: Reported wait reasons for completed jobs (not total queue time; excludes cancelled/unfinished jobs)
  columns:
  - name: package_name
    label: 包名
    label_i18n:
      en: Package
    type: string
  - name: uid
    label: UID
    label_i18n:
      en: UID
    type: number
  - name: pending_reason
    label: 等待原因
    label_i18n:
      en: Wait reason
    type: string
  - name: completed_job_count
    label: 已完成任务数
    label_i18n:
      en: Completed jobs
    type: number
  - name: known_duration_count
    label: 已知时长条目数
    label_i18n:
      en: Entries with a duration
    type: number
  - name: missing_duration_count
    label: 缺失时长条目数
    label_i18n:
      en: Entries missing a duration
    type: number
  - name: reported_wait_ms
    label: 已知上报等待时长（未按窗口裁剪）
    label_i18n:
      en: Known reported wait (not window-clipped)
    type: duration
    format: duration_ms
    unit: ms
```
