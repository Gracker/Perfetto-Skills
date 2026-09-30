GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/cpu_frequency_limit_attribution.skill.yaml
Source SHA-256: f5beaea78119cdb6f540a97c523e8d6f627f979431d0ad46b2e438ba486fe56c
# CPU 限频归因

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_frequency_limit_attribution
version: '1.0'
type: composite
category: thermal
tier: S
```

## Metadata

```yaml
display_name: CPU 限频归因
description: 从限频事件出发，回答谁触发了限频、限频前系统在做什么、是否存在异常线程，并列出可供进一步探索的厂商信号
icon: thermostat_auto
tags:
- cpu
- frequency
- limit
- thermal
- throttling
- attribution
- who
```

## Triggers

```yaml
keywords:
  zh:
  - 限频
  - 温控
  - 降频原因
  - 热限频
  - 谁触发
  - 限频原因
  - 频率被限
  en:
  - frequency limit
  - throttling cause
  - thermal cap
  - who throttled
  - cpu limited
patterns:
- .*(限频|温控|热限频).*
- .*降频.*(原因|为什么|谁).*
- .*谁.*(触发|导致).*(限频|降频|温控).*
- .*(frequency|freq).*(limit|cap|throttl).*
- .*throttling.*cause.*
```

## Prerequisites

```yaml
required_tables:
- counter
- counter_track
- cpu_counter_track
modules:
- linux.cpu.frequency
- android.process_metadata
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标包名/进程名（可选）
- name: process_name
  type: string
  required: false
  description: 目标进程名别名；package 为空时使用
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)；缺省使用观测数据起点
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)；缺省使用 trace 数据终点
- name: lookback_ms
  type: number
  required: false
  default: 10000
  description: 每个限频区段向前回溯的负载窗口长度(ms)
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
- name: cdev_policy_pair_ms
  type: number
  required: false
  default: 1
  description: 散热设备档位变更与其后 policy 上限变更的前向配对窗口(ms)；只有上限在档位变更之后该时间内变化才算一对
- name: cdev_policy_min_transitions
  type: number
  required: false
  default: 3
  description: 判定散热设备与 policy 关联所需的最少档位变更次数
- name: cdev_policy_min_pair_pct
  type: number
  required: false
  default: 80
  description: 判定关联所需的配对占比与同向占比下限(%)
- name: max_episodes
  type: number
  required: false
  default: 3
  description: 深入分析的限频区段数量上限
- name: episode_drop_pct
  type: number
  required: false
  default: 10
  description: 判定限频区段的降幅阈值（相对本 trace 观测到的最大上限，%）
- name: merge_gap_ms
  type: number
  required: false
  default: 500
  description: 限频区段合并间隔(ms)
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
- name: max_discovery_rows
  type: number
  required: false
  default: 60
  description: 厂商信号候选返回行数上限
```

## Ordered execution

### 数据可用性检测

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_attribution/data_check.sql`](../sql/cpu_frequency_limit_attribution/data_check.sql)

```yaml
id: data_check
type: atomic
process_scope:
  role: global_context
display: false
sql_fragments:
- fragments/system_cpu_freq_limit_spans.sql
- fragments/thermal_cooling_spans.sql
- fragments/thermal_cdev_policy_association.sql
save_as: data_check
```
### 分析窗口

- ID: `analysis_window`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_attribution/analysis_window.sql`](../sql/cpu_frequency_limit_attribution/analysis_window.sql)

```yaml
id: analysis_window
type: atomic
process_scope:
  role: global_context
display:
  level: detail
  layer: overview
  title: 分析窗口
  columns:
  - name: window_start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: window_end_ts
    label: 结束
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: window_dur_ns
    label: 时长
    type: duration
    unit: ns
  - name: window_source
    label: 窗口来源
    type: string
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
save_as: analysis_window
```
### 限频概览

- ID: `limit_overview`
- Type: `skill`

```yaml
id: limit_overview
type: skill
skill: cpu_freq_limit_timeline
optional: true
params:
  start_ts: ${analysis_window.data?.[0]?.window_start_ts ?? null}
  end_ts: ${analysis_window.data?.[0]?.window_end_ts ?? null}
  episode_drop_pct: ${episode_drop_pct|10}
  merge_gap_ms: ${merge_gap_ms|500}
display:
  level: summary
save_as: limit_overview
```
### 散热设备概览

- ID: `cooling_overview`
- Type: `skill`

```yaml
id: cooling_overview
type: skill
skill: thermal_cooling_device_timeline
optional: true
condition: data_check.data?.[0]?.cooling_track_count > 0
params:
  start_ts: ${analysis_window.data?.[0]?.window_start_ts ?? null}
  end_ts: ${analysis_window.data?.[0]?.window_end_ts ?? null}
display:
  level: summary
save_as: cooling_overview
```
### 限频区段（按影响排序）

- ID: `episodes`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_attribution/episodes.sql`](../sql/cpu_frequency_limit_attribution/episodes.sql)

```yaml
id: episodes
type: atomic
optional: true
condition: data_check.data?.[0]?.has_max_limit_data === 1
process_scope:
  role: global_context
sql_fragments:
- fragments/observed_data_bounds.sql
- fragments/system_sched_spans.sql
- fragments/system_cpu_freq_limit_spans.sql
- fragments/system_cpu_freq_limit_episodes.sql
display:
  level: summary
  layer: list
  title: 限频区段（按 深度 x 时长 x 核心能力 排序）
  columns:
  - name: episode_id
    label: 区段
    type: string
  - name: trace_episode_id
    label: 全 trace 区段
    type: string
  - name: policy_cpu
    label: policy 首核
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: topology_source
    label: 拓扑来源
    type: string
  - name: episode_start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: episode_end_ts
    label: 结束
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: episode_dur_ns
    label: 持续
    type: duration
    unit: ns
  - name: onset_ts
    label: 限频起点
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: onset_observed
    label: 起点可观测
    type: boolean
  - name: min_limit_khz
    label: 最低上限
    type: number
  - name: reference_max_limit_khz
    label: 参考上限
    type: number
  - name: reference_basis
    label: 参考依据
    type: string
  - name: depth_pct
    label: 限频深度
    type: percentage
  - name: change_count
    label: 合并变更数
    type: number
  - name: starts_at_data_start
    label: 区段含轨道首样本
    type: boolean
  - name: ends_at_data_end
    label: 终点未知
    type: boolean
  - name: evidence_status
    label: 证据状态
    type: string
  - name: impact_rank_score
    label: 排序分
    type: number
    hidden: true
  - name: before_start_ts
    label: 回溯窗口开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: before_end_ts
    label: 回溯窗口结束
    type: timestamp
    unit: ns
    hidden: true
  - name: window_clipped_to_data_start
    label: 回溯窗口被裁剪
    type: boolean
  - name: who_start_ts
    label: 归因窗口开始
    type: timestamp
    unit: ns
    hidden: true
  - name: who_end_ts
    label: 归因窗口结束
    type: timestamp
    unit: ns
    hidden: true
  - name: window_start_ts
    label: 分析窗口开始
    type: timestamp
    unit: ns
    hidden: true
  - name: window_end_ts
    label: 分析窗口结束
    type: timestamp
    unit: ns
    hidden: true
  - name: package
    label: package
    type: string
    hidden: true
  - name: process_name
    label: process_name
    type: string
    hidden: true
  - name: lookback_ms
    label: lookback_ms
    type: number
    hidden: true
  - name: who_window_ms
    label: who_window_ms
    type: number
    hidden: true
  - name: cooling_coincidence_ms
    label: cooling_coincidence_ms
    type: number
    hidden: true
  - name: top_n
    label: top_n
    type: number
    hidden: true
  - name: sustained_pct
    label: sustained_pct
    type: number
    hidden: true
  - name: spin_avg_slice_us
    label: spin_avg_slice_us
    type: number
    hidden: true
  - name: spin_switches_per_s
    label: spin_switches_per_s
    type: number
    hidden: true
  - name: waker_per_s
    label: waker_per_s
    type: number
    hidden: true
  - name: kernel_daemon_share_pct
    label: kernel_daemon_share_pct
    type: number
    hidden: true
  - name: cdev_policy_pair_ms
    label: cdev_policy_pair_ms
    type: number
    hidden: true
  - name: cdev_policy_min_transitions
    label: cdev_policy_min_transitions
    type: number
    hidden: true
  - name: cdev_policy_min_pair_pct
    label: cdev_policy_min_pair_pct
    type: number
    hidden: true
  - name: episode_drop_pct
    label: episode_drop_pct
    type: number
    hidden: true
  - name: merge_gap_ms
    label: merge_gap_ms
    type: number
    hidden: true
  - name: thresholds
    label: 阈值
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 分析窗口内没有超过阈值的限频区段。可降低 episode_drop_pct 复查更浅的限频，或确认窗口是否覆盖限频时刻。
save_as: episode_rows
```
### 逐区段归因

- ID: `episode_drilldown`
- Type: `iterator`

```yaml
id: episode_drilldown
type: iterator
source: episode_rows
item_skill: cpu_frequency_limit_episode
max_items: 8
item_params:
  episode_id: episode_id
  trace_episode_id: trace_episode_id
  episode_start_ts: onset_ts
  episode_end_ts: episode_end_ts
  window_start_ts: window_start_ts
  window_end_ts: window_end_ts
  policy_cpu: policy_cpu
  core_type: core_type
  package: package
  process_name: process_name
  lookback_ms: lookback_ms
  who_window_ms: who_window_ms
  cooling_coincidence_ms: cooling_coincidence_ms
  top_n: top_n
  sustained_pct: sustained_pct
  spin_avg_slice_us: spin_avg_slice_us
  spin_switches_per_s: spin_switches_per_s
  waker_per_s: waker_per_s
  kernel_daemon_share_pct: kernel_daemon_share_pct
  cdev_policy_pair_ms: cdev_policy_pair_ms
  cdev_policy_min_transitions: cdev_policy_min_transitions
  cdev_policy_min_pair_pct: cdev_policy_min_pair_pct
  episode_drop_pct: episode_drop_pct
  merge_gap_ms: merge_gap_ms
display:
  level: key
  layer: deep
  title: 逐个限频区段的归因详情
  format: table
```
### 归因汇总

- ID: `attribution_summary`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_attribution/attribution_summary.sql`](../sql/cpu_frequency_limit_attribution/attribution_summary.sql)

```yaml
id: attribution_summary
type: atomic
optional: true
condition: episodes.data?.length > 0
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
- fragments/system_cpu_freq_limit_spans.sql
- fragments/system_cpu_freq_limit_episodes.sql
- fragments/thermal_cooling_spans.sql
- fragments/thermal_cdev_policy_association.sql
- fragments/thermal_signal_signatures.sql
- fragments/system_cpu_freq_limit_episode_verdicts.sql
- fragments/actor_class_labels.sql
display:
  level: key
  layer: overview
  title: 限频归因汇总
  columns:
  - name: classification
    label: 分类
    type: string
  - name: classification_scope
    label: 分类范围
    type: string
  - name: episode_count
    label: 区段数
    type: number
  - name: onset_count
    label: 限频写入次数
    type: number
  - name: confirmed_onset_count
    label: 由关联散热设备施加的写入
    type: number
  - name: causal_onset_count
    label: 收紧或起点未知的写入
    type: number
  - name: onset_trigger_mix
    label: 逐次写入分类
    type: string
  - name: deepest_depth_pct
    label: 最大限频深度
    type: percentage
  - name: longest_episode_ns
    label: 最长区段
    type: duration
    unit: ns
  - name: cooling_confirmed_episodes
    label: 判定为内核热控的区段
    type: number
  - name: daemon_suspected_episodes
    label: 以守护进程为最强证据的区段
    type: number
  - name: cooling_background_episodes
    label: 仅有关联散热设备背景活动的区段
    type: number
  - name: cooling_unassociated_episodes
    label: 仅有未关联散热设备活动的区段
    type: number
  - name: onset_unknown_episodes
    label: 起点不可观测的区段
    type: number
  - name: tied_cooling_devices
    label: 与 policy 时序关联的散热设备数
    type: number
  - name: cooling_transition_coverage
    label: 采集到散热设备档位变化
    type: boolean
  - name: top_episode_id
    label: 首要区段
    type: string
  - name: top_before_start_ts
    label: 首要区段回溯窗口开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: top_before_end_ts
    label: 首要区段回溯窗口结束
    type: timestamp
    unit: ns
    hidden: true
  - name: target_running_ns
    label: 目标应用限频前运行
    type: duration
    unit: ns
  - name: total_running_ns
    label: 限频前全部运行
    type: duration
    unit: ns
  - name: target_share_pct
    label: 目标应用占比
    type: percentage
  - name: target_dominated_before_limit
    label: 目标应用主导限频前负载
    type: string
  - name: target_scope
    label: 目标范围
    type: string
  - name: description
    label: 描述
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
save_as: attribution_summary
```
### 厂商温控信号候选

- ID: `vendor_signal_discovery`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_attribution/vendor_signal_discovery.sql`](../sql/cpu_frequency_limit_attribution/vendor_signal_discovery.sql)

```yaml
id: vendor_signal_discovery
type: atomic
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/thermal_signal_signatures.sql
display:
  level: detail
  layer: list
  title: 厂商温控/性能策略信号候选（名字匹配，供 execute_sql 进一步探索）
  columns:
  - name: candidate_kind
    label: 候选类型
    type: string
  - name: candidate_name
    label: 名称
    type: string
  - name: track_type
    label: 轨道类型
    type: string
  - name: source_process
    label: 来源进程
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
  - name: sample_count
    label: 样本数
    type: number
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
  - name: exploration_hint
    label: 探索提示
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 分析窗口内没有名字匹配温控/性能策略签名的计数器、slice 或线程。
save_as: vendor_signal_discovery
```
### 无限频数据时的频率观测

- ID: `no_limit_throttle_observation`
- Type: `skill`

```yaml
id: no_limit_throttle_observation
type: skill
skill: cpu_throttling_in_range
optional: true
condition: data_check.data?.[0]?.has_max_limit_data !== 1 && data_check.data?.[0]?.has_cpufreq_data === 1
params:
  start_ts: ${analysis_window.data?.[0]?.window_start_ts ?? null}
  end_ts: ${analysis_window.data?.[0]?.window_end_ts ?? null}
display:
  level: summary
save_as: no_limit_throttle_observation
```
### 限频数据缺失说明

- ID: `no_limit_capture_advice`
- Type: `atomic`
- SQL: [`../sql/cpu_frequency_limit_attribution/no_limit_capture_advice.sql`](../sql/cpu_frequency_limit_attribution/no_limit_capture_advice.sql)

```yaml
id: no_limit_capture_advice
type: atomic
condition: data_check.data?.[0]?.has_max_limit_data !== 1
process_scope:
  role: global_context
sql_fragments:
- fragments/system_cpu_freq_limit_spans.sql
display:
  level: key
  layer: overview
  title: 无法直接观测限频
  columns:
  - name: limit_evidence
    label: 限频证据
    type: string
  - name: classification
    label: 分类
    type: string
  - name: limit_evidence_missing_reason
    label: 缺失原因
    type: string
  - name: required_ftrace_event
    label: 需要采集的 ftrace 事件
    type: string
  - name: also_useful
    label: 同时建议采集
    type: string
  - name: message
    label: 说明
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
save_as: no_limit_capture_advice
```
### 限频归因诊断

- ID: `diagnosis`
- Type: `diagnostic`

```yaml
id: diagnosis
type: diagnostic
display:
  level: key
  layer: diagnosis
  title: 限频归因结论
inputs:
- data_check
- analysis_window
- episode_rows
- attribution_summary
- vendor_signal_discovery
rules:
- id: limit_evidence_missing
  condition: data_check.data?.[0]?.has_max_limit_data !== 1
  severity: info
  diagnosis: LIMIT_EVIDENCE_MISSING（${data_check.data[0].limit_evidence_missing_reason}）：本 trace 没有有效的 cpufreq 最大上限样本，无法判断是否发生限频；观测到的低频不能区分限频与负载下降
  confidence: low
  suggestions:
  - 系统侧：在采集配置中加入 ftrace 事件 power/cpu_frequency_limits，并尽量同时加入 thermal/cdev_update 与 thermal/thermal_temperature
  - App 侧：在拿到限频证据之前，不要把性能下降归因于温控；先用同窗口负载数据判断是否是自身工作量导致
- id: no_episode
  condition: data_check.data?.[0]?.has_max_limit_data === 1 && !(episodes.data?.length > 0)
  severity: info
  diagnosis: NO_LIMIT_EPISODE：窗口内存在有效的上限样本，但没有超过 ${episode_drop_pct|10}% 阈值的限频区段；未观测到显著限频
  confidence: medium
  suggestions:
  - 系统侧：如需排查更浅的限频，降低 episode_drop_pct 后重跑
  - App 侧：该窗口的性能问题更可能来自自身工作量或调度，而非频率上限
- id: thermal_limit_confirmed
  condition: attribution_summary.data?.[0]?.classification === 'THERMAL_LIMIT_CONFIRMED'
  severity: warning
  diagnosis: THERMAL_LIMIT_CONFIRMED：窗口内 ${attribution_summary.data[0].confirmed_onset_count}/${attribution_summary.data[0].causal_onset_count}
    次收紧类限频写入紧跟在与该 policy 时序关联的内核散热设备升档之后（涉及 ${attribution_summary.data[0].cooling_confirmed_episodes}/${attribution_summary.data[0].episode_count}
    段，最大限频深度 ${attribution_summary.data[0].deepest_depth_pct}%；逐次写入分类 ${attribution_summary.data[0].onset_trigger_mix}）
  confidence: high
  suggestions:
  - 系统侧：散热设备与 policy 的对应关系来自档位变更与上限变更的前向时序配对，不来自设备名；继续核对触发该散热设备的热区阈值
  - 系统侧：检查限频前回溯窗口内的温升与非 CPU 热源（充电、GPU、相机、Modem），温控不一定由 CPU 负载单独造成
  - App 侧：查看逐区段的限频前负载归因，确认目标应用是否主导了限频前的 CPU 工作量（target_dominated_before_limit=${attribution_summary.data[0].target_dominated_before_limit}）
  - App 侧：若目标应用主导，优先降低持续 CPU 工作量或把工作移出大核；若不主导，应用侧优化对本次限频的收益有限
- id: thermal_daemon_suspected
  condition: attribution_summary.data?.[0]?.classification === 'THERMAL_DAEMON_SUSPECTED'
  severity: warning
  diagnosis: THERMAL_DAEMON_SUSPECTED：没有限频写入由关联散热设备施加，但收紧前有名字匹配温控签名的守护进程在运行（共 ${attribution_summary.data[0].episode_count}
    段，最大深度 ${attribution_summary.data[0].deepest_depth_pct}%；逐次写入分类 ${attribution_summary.data[0].onset_trigger_mix}）；用户态温控是候选触发方，尚未证明因果
  confidence: medium
  suggestions:
  - 系统侧：该平台可能由用户态 thermal daemon 直接写 cpufreq sysfs 限频，不产生 cdev_update；用 execute_sql 查看候选守护进程的 slice 与厂商计数器以确认
  - 系统侧：守护进程在未限频时也会周期性运行，需比较归因窗口速率与全 trace 基线速率再下结论
  - App 侧：查看限频前负载归因，确认目标应用是否主导了限频前工作量（target_dominated_before_limit=${attribution_summary.data[0].target_dominated_before_limit}）
- id: thermal_cooling_background
  condition: attribution_summary.data?.[0]?.classification === 'THERMAL_COOLING_BACKGROUND'
  severity: info
  diagnosis: THERMAL_COOLING_BACKGROUND：与该 policy 时序关联的散热设备在限频期间处于非零档位或在写入附近换档，但没有一次收紧与其升档前向配对；属于并存的背景热控候选，不能确认施加者（逐次写入分类
    ${attribution_summary.data[0].onset_trigger_mix}）
  confidence: medium
  suggestions:
  - 系统侧：对照限频写入时刻与散热设备档位变更的先后顺序；只有上限紧跟在升档之后才是热控施加
  - App 侧：在触发方确认之前不要按温控优化；先用限频前负载归因判断自身工作量
- id: thermal_cooling_unassociated
  condition: attribution_summary.data?.[0]?.classification === 'THERMAL_COOLING_UNASSOCIATED'
  severity: info
  diagnosis: THERMAL_COOLING_UNASSOCIATED：限频期间只有未与该 policy 关联的散热设备有活动（关联依据为档位变更与上限变更的前向配对，不看设备名）；它们不能算作这次限频的施加者
  confidence: low
  suggestions:
  - 系统侧：散热设备可能治理其他 policy、GPU 或其他子系统；用 thermal_cooling_device_timeline 与 cpu_freq_limit_timeline 对照时序
  - App 侧：在触发方确认之前不要按温控优化
- id: limit_onset_unknown
  condition: attribution_summary.data?.[0]?.classification === 'LIMIT_ONSET_UNKNOWN'
  severity: info
  diagnosis: LIMIT_ONSET_UNKNOWN：窗口内限频值的写入时刻不可观测（轨道首样本即受限，或紧跟在无效样本之后）；只能报告受限时长与影响，不能判断触发方，也不能写成非热限频
  confidence: low
  suggestions:
  - 系统侧：从更早的时刻开始采集，以覆盖限频开始的时刻
  - App 侧：可评估受限期间的性能影响，但不要据此归因
- id: no_thermal_evidence_observed
  condition: attribution_summary.data?.[0]?.classification === 'NO_THERMAL_EVIDENCE_OBSERVED'
  severity: info
  diagnosis: NO_THERMAL_EVIDENCE_OBSERVED：观测到 ${attribution_summary.data[0].episode_count} 段限频；本 trace 采集到了散热设备档位变化，但没有一次收紧与关联散热设备配对或同期活动，也没有温控守护进程活动；未观测到热证据，但这不证明触发方是非热的
  confidence: low
  suggestions:
  - 系统侧：考虑非热的限频来源——性能策略/省电模式、后台限制、用户态 perf HAL 或 uclamp 上限；厂商信号候选表可作为 execute_sql 的探索起点
  - App 侧：在触发方确定之前不要按温控优化；先用限频前负载归因判断是否为自身工作量问题
- id: thermal_evidence_not_captured
  condition: attribution_summary.data?.[0]?.classification === 'THERMAL_EVIDENCE_NOT_CAPTURED'
  severity: info
  diagnosis: THERMAL_EVIDENCE_NOT_CAPTURED：观测到 ${attribution_summary.data[0].episode_count} 段限频，但本 trace 没有任何散热设备档位变化，无法把限频写入归因到内核热控；温度与守护进程名只能算线索，触发方无法判定
  confidence: low
  suggestions:
  - 系统侧：在采集配置中加入 thermal/cdev_update（以及 thermal/thermal_temperature）后重新采集；缺事件与无事件不可混同
  - App 侧：在触发方确定之前不要按温控优化；先用限频前负载归因判断是否为自身工作量问题
- id: limit_relaxed_only
  condition: attribution_summary.data?.[0]?.classification === 'LIMIT_RELAXED'
  severity: info
  diagnosis: LIMIT_RELAXED：窗口内只看到上限被放宽，造成受限的收紧发生在窗口之前；放宽不是限频原因，本窗口不判断触发方
  confidence: low
  suggestions:
  - 系统侧：扩大分析窗口以覆盖最初收紧的时刻
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- attribution_summary
- episodes
- diagnosis
```
