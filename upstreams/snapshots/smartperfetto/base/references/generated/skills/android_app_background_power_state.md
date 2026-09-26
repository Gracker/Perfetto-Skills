GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_app_background_power_state.skill.yaml
Source SHA-256: 4ce3166f6ef8db3eca68f7a14cb6d6164abb3f15de2db690e545acc15ef4ff86
Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799
# 应用后台功耗状态

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_app_background_power_state
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: 应用后台功耗状态
description: App wakelock（按 uid/tag）、standby bucket 驻留与 freezer 冻结区间三层可选证据；按数据与 trace processor 能力分别启用，旧 runtime 显式降级
icon: battery_saver
tags:
- power
- battery
- wakelock
- standby_bucket
- freezer
- background
```

## Triggers

```yaml
keywords:
  zh:
  - 应用 wakelock
  - 持锁耗电
  - 待机分组
  - standby bucket
  - 冻结
  - freezer
  - 后台耗电
  en:
  - app wakelock
  - standby bucket
  - app freezer
  - frozen app
  - background drain
patterns:
- .*(standby bucket|待机分组|app wakelock|应用.*wakelock).*
- .*(freezer|冻结).*(进程|app|process).*
```

## Prerequisites

```yaml
modules:
- android.app_wakelocks
- android.battery_stats
- android.standby_bucket
- android.freezer
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标包名或进程名（精确或 name:* 子进程）；留空返回全部应用
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)；时长按窗口裁剪
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
```

## Ordered execution

### 后台功耗证据能力检查

- ID: `power_state_capability`
- Type: `atomic`
- SQL: [`../sql/android_app_background_power_state/power_state_capability.sql`](../sql/android_app_background_power_state/power_state_capability.sql)

```yaml
id: power_state_capability
type: atomic
display:
  level: detail
  layer: overview
  title: 应用后台功耗证据：数据与 runtime 能力
  columns:
  - name: wakelock_status
    label: App wakelock
    type: string
  - name: standby_bucket_status
    label: Standby bucket
    type: string
  - name: standby_atom_count
    label: Standby atom 数
    type: number
  - name: freezer_status
    label: Freezer
    type: string
  - name: freeze_atom_count
    label: Freeze atom 数
    type: number
  - name: freezer_slice_count
    label: Freeze slice 数
    type: number
save_as: power_state_capability
```
### App wakelock 汇总

- ID: `app_wakelock_summary`
- Type: `atomic`
- SQL: [`../sql/android_app_background_power_state/app_wakelock_summary.sql`](../sql/android_app_background_power_state/app_wakelock_summary.sql)

```yaml
id: app_wakelock_summary
type: atomic
optional: true
condition: power_state_capability.data[0]?.wakelock_status === 'available'
display:
  level: key
  layer: list
  title: App wakelock（PowerManager 持锁，按 uid + tag，窗口内裁剪）
  columns:
  - name: uid
    label: UID
    type: number
  - name: user_id
    label: User
    type: number
  - name: packages
    label: 包/进程
    type: string
  - name: tag
    label: Wakelock tag
    type: string
  - name: wakelock_count
    label: 次数
    type: number
  - name: total_held_ms
    label: 总持有
    type: duration
    format: duration_ms
    unit: ms
  - name: max_held_ms
    label: 最长一次
    type: duration
    format: duration_ms
    unit: ms
  - name: source
    label: 来源
    type: string
save_as: app_wakelock_summary
```
### App wakelock 汇总（BatteryStats 回退）

- ID: `app_wakelock_summary_battery_stats`
- Type: `atomic`
- SQL: [`../sql/android_app_background_power_state/app_wakelock_summary_battery_stats.sql`](../sql/android_app_background_power_state/app_wakelock_summary_battery_stats.sql)

```yaml
id: app_wakelock_summary_battery_stats
type: atomic
optional: true
condition: power_state_capability.data[0]?.wakelock_status === 'available_via_battery_stats'
display:
  level: key
  layer: list
  title: App wakelock（BatteryStats longwake 回退，按 uid + tag，窗口内裁剪）
  columns:
  - name: uid
    label: UID
    type: number
  - name: user_id
    label: User
    type: number
  - name: packages
    label: 包/进程
    type: string
  - name: tag
    label: Wakelock tag
    type: string
  - name: wakelock_count
    label: 次数
    type: number
  - name: total_held_ms
    label: 总持有
    type: duration
    format: duration_ms
    unit: ms
  - name: max_held_ms
    label: 最长一次
    type: duration
    format: duration_ms
    unit: ms
  - name: source
    label: 来源
    type: string
save_as: app_wakelock_summary_battery_stats
```
### Standby bucket 驻留

- ID: `standby_bucket_residency`
- Type: `atomic`
- SQL: [`../sql/android_app_background_power_state/standby_bucket_residency.sql`](../sql/android_app_background_power_state/standby_bucket_residency.sql)

```yaml
id: standby_bucket_residency
type: atomic
optional: true
condition: power_state_capability.data[0]?.standby_bucket_status === 'available'
display:
  level: key
  layer: list
  title: App standby bucket 驻留（窗口内裁剪）
  columns:
  - name: package_name
    label: 包名
    type: string
  - name: user_id
    label: User
    type: number
  - name: bucket
    label: Bucket
    type: string
  - name: residency_ms
    label: 驻留时长
    type: duration
    format: duration_ms
    unit: ms
  - name: entry_count
    label: 进入次数
    type: number
  - name: last_main_reason
    label: 最近原因
    type: string
  - name: first_entered_ts
    label: 首次进入
    type: timestamp
    unit: ns
save_as: standby_bucket_residency
```
### Freezer 冻结汇总

- ID: `freezer_summary`
- Type: `atomic`
- SQL: [`../sql/android_app_background_power_state/freezer_summary.sql`](../sql/android_app_background_power_state/freezer_summary.sql)

```yaml
id: freezer_summary
type: atomic
optional: true
condition: power_state_capability.data[0]?.freezer_status === 'available_statsd'
display:
  level: key
  layer: list
  title: Freezer 冻结区间（statsd app_freeze_changed，按进程，窗口内裁剪）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: pid
    label: PID
    type: number
  - name: freeze_count
    label: 冻结次数
    type: number
  - name: total_frozen_ms
    label: 总冻结时长
    type: duration
    format: duration_ms
    unit: ms
  - name: max_frozen_ms
    label: 最长一次
    type: duration
    format: duration_ms
    unit: ms
  - name: top_unfreeze_reason
    label: 主要解冻原因
    type: string
  - name: source
    label: 来源
    type: string
save_as: freezer_summary
```
### Freezer 冻结汇总（slice 来源）

- ID: `freezer_summary_slices`
- Type: `atomic`
- SQL: [`../sql/android_app_background_power_state/freezer_summary_slices.sql`](../sql/android_app_background_power_state/freezer_summary_slices.sql)

```yaml
id: freezer_summary_slices
type: atomic
optional: true
condition: power_state_capability.data[0]?.freezer_status === 'available_slices'
display:
  level: key
  layer: list
  title: Freezer 冻结区间（Freeze/Unfreeze slice，按进程，窗口内裁剪）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: pid
    label: PID
    type: number
  - name: freeze_count
    label: 冻结次数
    type: number
  - name: total_frozen_ms
    label: 总冻结时长
    type: duration
    format: duration_ms
    unit: ms
  - name: max_frozen_ms
    label: 最长一次
    type: duration
    format: duration_ms
    unit: ms
  - name: top_unfreeze_reason
    label: 主要解冻原因
    type: string
  - name: source
    label: 来源
    type: string
save_as: freezer_summary_slices
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: power_state_capability
  description: 'Per layer status: available, available_via_battery_stats / available_slices (older-runtime-compatible sources),
    runtime_lacks_* (data present but the trace processor predates the module) or no_*_data; includes raw atom and slice counts'
- name: app_wakelock_summary
  description: Application (PowerManager) wakelocks by uid and tag with packages resolved from package_list and process uids;
    not kernel wakeup sources
- name: standby_bucket_residency
  description: Per package standby bucket residency within the window and the latest main reason
- name: app_wakelock_summary_battery_stats
  description: Same shape as app_wakelock_summary from BatteryStats longwake events, for trace processors without android.app_wakelocks
- name: freezer_summary
  description: Per process frozen intervals from statsd app_freeze_changed atoms and the dominant unfreeze reason
- name: freezer_summary_slices
  description: Same shape as freezer_summary from Freeze/Unfreeze slices; used when there are no freeze atoms or the runtime
    lacks the statsd view
```
