GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# 休眠唤醒分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: suspend_wakeup_analysis
version: '3.0'
type: composite
category: power
tier: S
```

## Metadata

```yaml
display_name: 休眠唤醒分析
description: 分析系统挂起和唤醒原因、休眠质量和功耗影响
icon: power_settings_new
tags:
- power
- suspend
- wakeup
- kernel
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 休眠
  - 挂起
  - 唤醒
  - 待机
  - 功耗
  - 电池
  - 保活
  - wakelock
  en:
  - suspend
  - wakeup
  - sleep
  - standby
  - power
  - battery
  - keep awake
  - wakelock
patterns:
- .*休眠.*
- .*suspend.*
- .*唤醒.*
- .*wakeup.*
- .*(电池|battery|功耗|power).*
- .*(保活|keep.?awake|wakelock).*
```

## Prerequisites

```yaml
required_tables:
- sched_slice
modules:
- android.suspend
- android.wakeups
```

## Inputs

```yaml
- name: wakeup_source
  type: string
  required: false
  description: 唤醒源过滤（可选）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
- name: frequent_wakeup_critical
  type: number
  required: false
  default: 50
  description: 频繁唤醒严重阈值（次数）
- name: frequent_wakeup_warning
  type: number
  required: false
  default: 20
  description: 频繁唤醒警告阈值（次数）
- name: abort_pct_critical
  type: number
  required: false
  default: 30
  description: Suspend 中止率严重阈值（%）
- name: abort_pct_warning
  type: number
  required: false
  default: 10
  description: Suspend 中止率警告阈值（%）
- name: low_suspend_pct
  type: number
  required: false
  default: 30
  description: 休眠占比过低警告阈值（%）
```

## Ordered execution

### 检查休眠数据

- ID: `check_suspend_data`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/check_suspend_data.sql`](../sql/suspend_wakeup_analysis/check_suspend_data.sql)

```yaml
id: check_suspend_data
type: atomic
display: false
optional: true
save_as: suspend_check
```
### 检查唤醒数据

- ID: `check_wakeup_data`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/check_wakeup_data.sql`](../sql/suspend_wakeup_analysis/check_wakeup_data.sql)

```yaml
id: check_wakeup_data
type: atomic
display: false
optional: true
save_as: wakeup_check
condition: suspend_check.data[0]?.status === 'available'
```
### 检查 Suspend Slice 数据

- ID: `check_suspend_slices`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/check_suspend_slices.sql`](../sql/suspend_wakeup_analysis/check_suspend_slices.sql)

```yaml
id: check_suspend_slices
type: atomic
display: false
save_as: suspend_slice_check
condition: suspend_check.data[0]?.status === 'unavailable'
```
### 休眠唤醒概览

- ID: `suspend_overview`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/suspend_overview.sql`](../sql/suspend_wakeup_analysis/suspend_overview.sql)

```yaml
id: suspend_overview
type: atomic
optional: true
synthesize:
  role: overview
  fields:
  - key: suspended_pct
    label: 休眠占比
    format: '{{value}}%'
  - key: awake_pct
    label: 唤醒占比
    format: '{{value}}%'
  - key: suspend_count
    label: 休眠次数
  - key: rating
    label: 评级
  insights:
  - condition: suspended_pct < 50
    template: 休眠时间占比仅 {{suspended_pct}}%，设备难以进入深度休眠
  - condition: awake_count > 50
    template: 唤醒次数多达 {{awake_count}} 次，频繁唤醒影响续航
display:
  level: key
  layer: overview
  title: 休眠唤醒概览
  columns:
  - name: power_state
    label: 电源状态
    type: string
  - name: period_count
    label: 周期数
    type: number
    format: compact
  - name: total_time_sec
    label: 总时间 (秒)
    type: number
    format: compact
  - name: avg_duration_sec
    label: 平均时长 (秒)
    type: number
    format: compact
  - name: max_duration_sec
    label: 最长时长 (秒)
    type: number
    format: compact
  - name: min_duration_sec
    label: 最短时长 (秒)
    type: number
    format: compact
save_as: suspend_overview
condition: suspend_check.data[0]?.status === 'available'
```
### 休眠质量评估

- ID: `suspend_quality_assessment`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/suspend_quality_assessment.sql`](../sql/suspend_wakeup_analysis/suspend_quality_assessment.sql)

```yaml
id: suspend_quality_assessment
type: atomic
optional: true
synthesize:
  role: overview
  fields:
  - key: suspend_pct
    label: 休眠占比
    format: '{{value}}%'
  - key: abort_pct
    label: 失败率
    format: '{{value}}%'
  - key: total_wakeups
    label: 总唤醒次数
  - key: wakeups_per_min
    label: 唤醒频率
    format: '{{value}}/min'
display:
  level: key
  layer: overview
  title: 休眠质量综合评估
  columns:
  - name: suspend_pct
    label: 休眠占比 (%)
    type: percentage
  - name: awake_pct
    label: 唤醒占比 (%)
    type: percentage
  - name: total_wakeups
    label: 总唤醒次数
    type: number
    format: compact
  - name: wakeups_per_min
    label: 唤醒/分钟
    type: number
    format: compact
  - name: abort_count
    label: Suspend 中止次数
    type: number
    format: compact
  - name: bad_quality_count
    label: 低质量唤醒
    type: number
    format: compact
  - name: abort_pct
    label: 中止率 (%)
    type: percentage
  - name: max_backoff_ms
    label: 最大 Backoff(ms)
    type: duration
    unit: ms
    format: duration_ms
save_as: suspend_quality
condition: suspend_check.data[0]?.status === 'available'
```
### 唤醒事件类型分布

- ID: `wakeup_type_overview`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/wakeup_type_overview.sql`](../sql/suspend_wakeup_analysis/wakeup_type_overview.sql)

```yaml
id: wakeup_type_overview
type: atomic
optional: true
synthesize:
  role: list
  groupBy:
  - field: wakeup_type
    title: 按唤醒类型分布
  - field: suspend_quality
    title: 按休眠质量分布
  fields:
  - key: wakeup_type
    label: 唤醒类型
  - key: wakeup_count
    label: 次数
  - key: total_awake_time_sec
    label: 唤醒时间
    format: '{{value}} 秒'
display:
  level: key
  layer: overview
  title: 唤醒事件类型分布
  columns:
  - name: wakeup_type
    label: 唤醒类型
    type: string
  - name: suspend_quality
    label: 休眠质量
    type: string
  - name: wakeup_count
    label: 唤醒次数
    type: number
    format: compact
  - name: total_awake_time_sec
    label: 总唤醒时间 (秒)
    type: number
    format: compact
  - name: avg_awake_time_sec
    label: 平均唤醒时长 (秒)
    type: number
    format: compact
save_as: wakeup_type_overview
condition: suspend_check.data[0]?.status === 'available' && wakeup_check.data[0]?.status === 'available'
```
### 唤醒源排行

- ID: `wakeup_source_ranking`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/wakeup_source_ranking.sql`](../sql/suspend_wakeup_analysis/wakeup_source_ranking.sql)

```yaml
id: wakeup_source_ranking
type: atomic
optional: true
synthesize:
  role: list
  groupBy:
  - field: wakeup_source
    title: 按唤醒源分布
  fields:
  - key: wakeup_source
    label: 唤醒源
  - key: wakeup_count
    label: 唤醒次数
  - key: total_awake_sec
    label: 总唤醒时间
    format: '{{value}} 秒'
display:
  level: key
  layer: list
  title: 唤醒源排行
  columns:
  - name: wakeup_source
    label: 唤醒源
    type: string
  - name: wakeup_type
    label: 唤醒类型
    type: string
  - name: wakeup_count
    label: 唤醒次数
    type: number
    format: compact
  - name: total_awake_sec
    label: 总唤醒时间 (秒)
    type: number
    format: compact
  - name: avg_awake_sec
    label: 平均唤醒时长 (秒)
    type: number
    format: compact
save_as: wakeup_source_ranking
condition: suspend_check.data[0]?.status === 'available' && wakeup_check.data[0]?.status === 'available'
```
### Suspend Backoff 分析

- ID: `suspend_backoff`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/suspend_backoff.sql`](../sql/suspend_wakeup_analysis/suspend_backoff.sql)

```yaml
id: suspend_backoff
type: atomic
optional: true
display:
  level: key
  layer: list
  title: Suspend Backoff 分析
  columns:
  - name: backoff_reason
    label: Backoff 原因
    type: string
  - name: backoff_state
    label: Backoff 状态
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: max_backoff_count
    label: 最大连续次数
    type: number
  - name: max_backoff_ms
    label: 最大延迟
    type: duration
    unit: ms
    format: duration_ms
  - name: avg_backoff_ms
    label: 平均延迟
    type: duration
    unit: ms
    format: duration_ms
save_as: suspend_backoff
condition: suspend_check.data[0]?.status === 'available' && wakeup_check.data[0]?.status === 'available'
```
### 唤醒事件时间线

- ID: `wakeup_timeline`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/wakeup_timeline.sql`](../sql/suspend_wakeup_analysis/wakeup_timeline.sql)

```yaml
id: wakeup_timeline
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 唤醒事件时间线
  columns:
  - name: event_ts
    label: 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: awake_duration_sec
    label: 唤醒时长 (秒)
    type: number
    format: compact
  - name: wakeup_type
    label: 唤醒类型
    type: string
  - name: wakeup_source
    label: 唤醒源
    type: string
  - name: suspend_quality
    label: 休眠质量
    type: string
  - name: on_device_attribution
    label: 设备归因
    type: string
save_as: wakeup_timeline
condition: suspend_check.data[0]?.status === 'available' && wakeup_check.data[0]?.status === 'available'
```
### 长时间休眠事件

- ID: `long_suspend_events`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/long_suspend_events.sql`](../sql/suspend_wakeup_analysis/long_suspend_events.sql)

```yaml
id: long_suspend_events
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 长时间休眠事件（Top 20）
  columns:
  - name: event_ts
    label: 开始时间
    type: timestamp
    clickAction: navigate_timeline
  - name: power_state
    label: 状态
    type: string
  - name: duration_sec
    label: 持续时长 (秒)
    type: number
    format: compact
save_as: long_suspend_events
condition: suspend_check.data[0]?.status === 'available'
```
### Suspend/Wakeup 相关 Slice

- ID: `suspend_slice_overview`
- Type: `atomic`
- SQL: [`../sql/suspend_wakeup_analysis/suspend_slice_overview.sql`](../sql/suspend_wakeup_analysis/suspend_slice_overview.sql)

```yaml
id: suspend_slice_overview
type: atomic
display:
  level: key
  layer: overview
  title: Suspend/Wakeup 相关 Slice（无 stdlib 数据时）
  columns:
  - name: slice_name
    label: Slice 名称
    type: string
  - name: count
    label: 出现次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
save_as: suspend_slice_overview
condition: suspend_check.data[0]?.status === 'unavailable' && suspend_slice_check.data[0]?.status === 'available'
```
### 休眠唤醒诊断

- ID: `suspend_diagnosis`
- Type: `diagnostic`

```yaml
id: suspend_diagnosis
type: diagnostic
synthesize:
  role: conclusion
  fields:
  - key: diagnosis
    label: 诊断结论
  - key: severity
    label: 严重程度
  - key: confidence
    label: 置信度
  insights:
  - template: 休眠唤醒诊断：{{diagnosis}}
display:
  level: key
  layer: overview
  title: 问题诊断
inputs:
- suspend_overview
- suspend_quality
- wakeup_type_overview
- wakeup_source_ranking
- suspend_backoff
rules:
- condition: wakeup_source_ranking.data[0]?.wakeup_count > ${frequent_wakeup_critical|50}
  severity: critical
  diagnosis: FREQUENT_WAKEUP - 唤醒源 '${wakeup_source_ranking.data[0].wakeup_source}' 唤醒 ${wakeup_source_ranking.data[0].wakeup_count}
    次
  confidence: high
  suggestions:
  - 检查该唤醒源对应的驱动或服务
  - 减少不必要的定时唤醒
  - 使用 AlarmManager 合并唤醒请求
- condition: wakeup_source_ranking.data[0]?.wakeup_count > ${frequent_wakeup_warning|20}
  severity: warning
  diagnosis: FREQUENT_WAKEUP - 唤醒源 '${wakeup_source_ranking.data[0].wakeup_source}' 唤醒 ${wakeup_source_ranking.data[0].wakeup_count}
    次
  confidence: medium
  suggestions:
  - 检查唤醒频率是否合理
  - 考虑延长唤醒间隔
- condition: suspend_quality.data[0]?.abort_pct > ${abort_pct_critical|30}
  severity: critical
  diagnosis: LONG_SUSPEND - Suspend 中止率高达 ${suspend_quality.data[0].abort_pct}%，设备难以进入休眠
  confidence: high
  suggestions:
  - 检查阻止 suspend 的内核模块或驱动
  - 检查 wakelock 持有情况
  - 排查 suspend_quality = 'bad' 的唤醒事件
- condition: suspend_quality.data[0]?.abort_pct > ${abort_pct_warning|10}
  severity: warning
  diagnosis: LONG_SUSPEND - Suspend 中止率 ${suspend_quality.data[0].abort_pct}%
  confidence: medium
  suggestions:
  - 检查 suspend 失败的 backoff 原因
  - 排查是否有持续持有 wakelock 的进程
- condition: suspend_quality.data[0]?.suspend_pct < ${low_suspend_pct|30}
  severity: warning
  diagnosis: LONG_SUSPEND - 休眠时间占比仅 ${suspend_quality.data[0].suspend_pct}%
  confidence: medium
  suggestions:
  - 设备大部分时间处于唤醒状态
  - 检查是否有后台活动阻止休眠
- condition: suspend_quality.data[0]?.suspend_pct >= 50 && suspend_quality.data[0]?.abort_pct <= ${abort_pct_warning|10}
  severity: info
  diagnosis: SUSPEND_NORMAL - 休眠质量正常（休眠占比 ${suspend_quality.data[0].suspend_pct}%，中止率 ${suspend_quality.data[0].abort_pct}%）
  confidence: high
  suggestions:
  - 休眠唤醒行为在正常范围内
```
### Fallback 诊断

- ID: `fallback_diagnosis`
- Type: `diagnostic`

```yaml
id: fallback_diagnosis
type: diagnostic
synthesize:
  role: conclusion
  fields:
  - key: diagnosis
    label: 诊断结论
  - key: severity
    label: 严重程度
  insights:
  - template: '{{diagnosis}}'
display:
  level: key
  layer: overview
  title: 数据可用性诊断
inputs:
- suspend_check
- suspend_slice_check
rules:
- condition: suspend_check.data[0]?.status === 'unavailable' && (!suspend_slice_check.data || suspend_slice_check.data[0]?.status
    === 'unavailable')
  severity: info
  diagnosis: 未检测到休眠唤醒数据。Trace 中未包含 android.suspend 模块数据，也未发现 suspend/wakeup 相关 Slice。如需分析休眠问题，请在录制 Trace 时启用 power 相关数据源。
  confidence: high
  suggestions:
  - 录制 Trace 时启用 android.suspend 和 android.wakeups 模块
  - 确保录制时间覆盖设备待机周期
condition: suspend_check.data[0]?.status === 'unavailable'
```
