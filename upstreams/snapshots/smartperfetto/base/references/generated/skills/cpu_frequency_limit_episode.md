GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/cpu_frequency_limit_episode.skill.yaml
Source SHA-256: b02b4e752ee6809352b02fbf8267c6cd3900768a842fe46ba886cfc61a79bbbd
Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad
# 限频区段归因详情

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_frequency_limit_episode
version: '1.0'
type: composite
category: thermal
tier: A
```

## Metadata

```yaml
display_name: 限频区段归因详情
description: 对单个限频区段回溯散热设备、温控守护、限频前负载、异常线程与非 CPU 热源；仅给出证据与候选，不断言因果
icon: travel_explore
tags:
- cpu
- frequency
- limit
- thermal
- attribution
- episode
- drilldown
```

## Prerequisites

```yaml
required_tables:
- counter
- counter_track
- sched_slice
modules:
- linux.cpu.frequency
- android.process_metadata
```

## Inputs

```yaml
- name: episode_id
  type: string
  required: false
  description: 区段标识（由上层传入）
- name: episode_start_ts
  type: timestamp
  required: true
  description: 区段开始时间戳(ns)
- name: episode_end_ts
  type: timestamp
  required: true
  description: 区段结束时间戳(ns)
- name: policy_cpu
  type: number
  required: false
  description: cpufreq policy 首核编号
- name: core_type
  type: string
  required: false
  description: 核心类型（可能为 unknown）
- name: starts_at_data_start
  type: number
  required: false
  default: 0
  description: 区段首个样本即轨道首样本时为 1，表示起点在数据之外、不可知
- name: lookback_ms
  type: number
  required: false
  default: 10000
  description: 限频前回溯窗口长度(ms)
- name: who_window_ms
  type: number
  required: false
  default: 2000
  description: 限频时刻前后的归因窗口半径(ms)
- name: cooling_coincidence_ms
  type: number
  required: false
  default: 50
  description: 散热设备档位变更与限频时刻的重合容差(ms)；重合才视为该次限频由内核热控直接施加
- name: package
  type: string
  required: false
  description: 目标包名/进程名
- name: process_name
  type: string
  required: false
  description: 目标进程名别名
- name: top_n
  type: number
  required: false
  default: 30
  description: 负载/异常线程返回上限
- name: sustained_pct
  type: number
  required: false
  default: 80
  description: 异常线程：持续占用阈值(%)
- name: spin_avg_slice_us
  type: number
  required: false
  default: 200
  description: 异常线程：疑似空转平均片长上限(us)
- name: spin_switches_per_s
  type: number
  required: false
  default: 2000
  description: 异常线程：疑似空转每秒片数下限
- name: waker_per_s
  type: number
  required: false
  default: 500
  description: 异常线程：唤醒风暴阈值(次/秒)
- name: kernel_daemon_share_pct
  type: number
  required: false
  default: 10
  description: 异常线程：内核守护重载阈值(%)
```

## Ordered execution

### 区段分析窗口

- ID: `episode_windows`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_episode/episode_windows.sql`](../sql/cpu_frequency_limit_episode/episode_windows.sql)

```yaml
id: episode_windows
type: atomic
process_scope:
  role: global_context
sql_fragments:
- fragments/observed_data_bounds.sql
display:
  level: detail
  layer: overview
  title: 区段分析窗口
  columns:
  - name: episode_id
    label: 区段
    type: string
  - name: policy_cpu
    label: policy 首核
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: episode_start_ts
    label: 区段开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: episode_end_ts
    label: 区段结束
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: before_start_ts
    label: 回溯窗口开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: before_end_ts
    label: 回溯窗口结束
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: before_window_ns
    label: 回溯窗口时长
    type: duration
    unit: ns
  - name: window_clipped_to_data_start
    label: 回溯窗口被数据起点裁剪
    type: boolean
  - name: who_start_ts
    label: 归因窗口开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: who_end_ts
    label: 归因窗口结束
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: who_window_clipped
    label: 归因窗口被数据边界裁剪
    type: boolean
  - name: starts_at_data_start
    label: 起点未知
    type: boolean
  - name: data_start_ts
    label: 数据起点
    type: timestamp
    unit: ns
    hidden: true
  - name: data_end_ts
    label: 数据终点
    type: timestamp
    unit: ns
    hidden: true
  - name: window_basis
    label: 窗口依据
    type: string
save_as: episode_windows
```
### 归因窗口内散热设备活动

- ID: `who_cooling`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_episode/who_cooling.sql`](../sql/cpu_frequency_limit_episode/who_cooling.sql)

```yaml
id: who_cooling
type: atomic
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/thermal_cooling_spans.sql
display:
  level: summary
  layer: list
  title: 限频前后的散热设备活动
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: rel_to_limit_ns
    label: 相对限频时刻
    type: duration
    unit: ns
  - name: cdev_name
    label: 散热设备
    type: string
  - name: cdev_kind_hint
    label: 疑似作用域
    type: string
  - name: cdev_kind_basis
    label: 判定依据
    type: string
  - name: prev_state
    label: 变更前
    type: number
  - name: state
    label: 变更后
    type: number
  - name: direction
    label: 方向
    type: string
  - name: dur_ns
    label: 保持时长
    type: duration
    unit: ns
  - name: cooling_source
    label: 数据来源
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 归因窗口内没有内核散热设备事件。该平台可能没有 cdev_update，或热控由用户态守护进程直接写 sysfs 完成。
save_as: who_cooling
```
### 归因窗口内温控/性能策略守护进程活动

- ID: `who_daemon`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_episode/who_daemon.sql`](../sql/cpu_frequency_limit_episode/who_daemon.sql)

```yaml
id: who_daemon
type: atomic
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/thermal_signal_signatures.sql
display:
  level: summary
  layer: list
  title: 限频前后的温控/性能策略守护进程活动（名字匹配，仅候选）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: signature_kind
    label: 签名类别
    type: string
  - name: platform_hint
    label: 平台提示
    type: string
  - name: matched_pattern
    label: 命中模式
    type: string
  - name: who_running_ns
    label: 归因窗口运行
    type: duration
    unit: ns
  - name: who_slice_count
    label: 归因窗口调度片
    type: number
  - name: who_rate_ns_per_s
    label: 归因窗口速率(ns/s)
    type: number
  - name: baseline_rate_ns_per_s
    label: 全 trace 基线速率(ns/s)
    type: number
  - name: rate_ratio
    label: 速率倍数
    type: number
  - name: ran_before_limit_ns
    label: 限频前运行
    type: duration
    unit: ns
  - name: last_run_end_before_ts
    label: 限频前最后一次运行结束
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: lead_ns
    label: 距离限频时刻
    type: duration
    unit: ns
  - name: match_basis
    label: 匹配依据
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 归因窗口内没有名字匹配温控/性能策略签名的线程在运行。
save_as: who_daemon
```
### 限频前温度上下文

- ID: `temperature_context`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_episode/temperature_context.sql`](../sql/cpu_frequency_limit_episode/temperature_context.sql)

```yaml
id: temperature_context
type: atomic
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/thermal_sample_quality.sql
display:
  level: summary
  layer: list
  title: 限频前回溯窗口内的温度
  columns:
  - name: sensor_name
    label: 传感器/热区
    type: string
  - name: sample_count_in_window
    label: 窗口采样数
    type: number
  - name: track_basis
    label: 轨道依据
    type: string
  - name: unit_basis
    label: 单位依据
    type: string
  - name: sample_quality
    label: 样本质量
    type: string
  - name: first_temp_c
    label: 窗口起始温度
    type: number
  - name: last_temp_c
    label: 窗口结束温度
    type: number
  - name: max_temp_c
    label: 窗口最高温度
    type: number
  - name: rise_c
    label: 窗口内升温
    type: number
  - name: first_ts
    label: 首个采样
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: last_ts
    label: 最后采样
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: temperature_evidence
    label: 温度证据
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 回溯窗口内没有温度采样。部分平台温度上报非常稀疏（每分钟数次），窗口内无样本不代表温度未变化。
save_as: temperature_context
```
### 限频前负载归因

- ID: `before_workload`
- Type: `skill`

```yaml
id: before_workload
type: skill
skill: cpu_workload_attribution_in_range
optional: true
params:
  start_ts: ${episode_windows.data?.[0]?.before_start_ts}
  end_ts: ${episode_windows.data?.[0]?.before_end_ts}
  package: ${package || ''}
  process_name: ${process_name || ''}
  top_n: ${top_n|30}
display:
  level: summary
save_as: before_workload
```
### 限频前异常线程

- ID: `before_anomalies`
- Type: `skill`

```yaml
id: before_anomalies
type: skill
skill: cpu_anomalous_threads_in_range
optional: true
params:
  start_ts: ${episode_windows.data?.[0]?.before_start_ts}
  end_ts: ${episode_windows.data?.[0]?.before_end_ts}
  package: ${package || ''}
  process_name: ${process_name || ''}
  sustained_pct: ${sustained_pct|80}
  spin_avg_slice_us: ${spin_avg_slice_us|200}
  spin_switches_per_s: ${spin_switches_per_s|2000}
  waker_per_s: ${waker_per_s|500}
  kernel_daemon_share_pct: ${kernel_daemon_share_pct|10}
  top_n: ${top_n|30}
display:
  level: summary
save_as: before_anomalies
```
### 限频前非 CPU 热源上下文

- ID: `non_cpu_heat_context`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_episode/non_cpu_heat_context.sql`](../sql/cpu_frequency_limit_episode/non_cpu_heat_context.sql)

```yaml
id: non_cpu_heat_context
type: atomic
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/thermal_signal_signatures.sql
display:
  level: detail
  layer: list
  title: 限频前回溯窗口内的非 CPU 热源迹象（仅存在性观测）
  columns:
  - name: source_kind
    label: 来源类别
    type: string
  - name: source_key
    label: 来源
    type: string
  - name: detail
    label: 明细
    type: string
  - name: observed_count
    label: 观测数
    type: number
  - name: running_ns
    label: 运行时长
    type: duration
    unit: ns
  - name: first_ts
    label: 首次
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: last_ts
    label: 最后
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: interpretation
    label: 解释边界
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 回溯窗口内没有观测到非 CPU 热源相关的计数器或进程活动。
save_as: non_cpu_heat_context
```
### 触发方判定

- ID: `who_verdict`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_episode/who_verdict.sql`](../sql/cpu_frequency_limit_episode/who_verdict.sql)

```yaml
id: who_verdict
type: atomic
process_scope:
  role: global_context
sql_fragments:
- fragments/thermal_cooling_spans.sql
- fragments/thermal_signal_signatures.sql
display:
  level: key
  layer: overview
  title: 谁触发了这次限频（证据判定）
  columns:
  - name: episode_id
    label: 区段
    type: string
  - name: policy_cpu
    label: policy 首核
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: who_verdict
    label: 判定
    type: string
  - name: cooling_transition_coincident
    label: 档位变更与限频时刻重合
    type: boolean
  - name: cooling_nearest_transition_ns
    label: 最近档位变更时间差
    type: duration
    unit: ns
  - name: cooling_nearest_transition_ts
    label: 最近档位变更时刻
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: cooling_active_ns
    label: 区段内散热设备生效时长
    type: duration
    unit: ns
  - name: cooling_devices_active
    label: 生效散热设备数
    type: number
  - name: cooling_transitions_in_who_window
    label: 归因窗口内散热档位变更
    type: number
  - name: daemon_ran_before_limit_ns
    label: 限频前守护进程运行
    type: duration
    unit: ns
  - name: daemon_threads_before_limit
    label: 限频前活跃守护线程数
    type: number
  - name: onset_observed
    label: 起点可观测
    type: boolean
  - name: onset_note
    label: 起点说明
    type: string
  - name: thresholds
    label: 阈值
    type: string
  - name: verdict_basis
    label: 判定依据
    type: string
  - name: interpretation
    label: 解释边界
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
save_as: who_verdict
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- who_verdict
- who_cooling
- who_daemon
```
