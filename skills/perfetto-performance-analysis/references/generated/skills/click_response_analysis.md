GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/click_response_analysis.skill.yaml
Source SHA-256: 0f803fbe7f82fcbcf288bfe2fb88bab8e0ad54cb2df2995d710a285a31b733c6
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# 点击响应分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: click_response_analysis
version: '1.0'
type: composite
category: interaction
tier: S
```

## Metadata

```yaml
display_name: 点击响应分析
description: 分析已完成 ACK 的点击事件响应延迟，并在有帧关联时补充 input-to-frame 延迟
icon: touch_app
tags:
- click
- latency
- interaction
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 点击
  - 点击响应
  - 触摸
  - 输入延迟
  - 点击慢
  - 响应慢
  - 点击卡顿
  en:
  - click
  - tap
  - touch
  - input latency
  - response time
  - click delay
patterns:
- .*点击.*慢.*
- .*点击.*卡.*
- .*响应.*延迟.*
- .*input.*latency.*
```

## Prerequisites

```yaml
modules:
- android.input
- android.binder
- android.frames.timeline
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
- name: slow_event_threshold_ms
  type: number
  required: false
  default: 100
  description: 慢输入事件阈值（ms，超过该值视为慢事件）
- name: avg_latency_critical_ms
  type: number
  required: false
  default: 100
  description: 平均延迟-严重阈值（ms）
- name: avg_handling_warning_ms
  type: number
  required: false
  default: 50
  description: 应用处理延迟-警告阈值（ms）
- name: avg_dispatch_warning_ms
  type: number
  required: false
  default: 20
  description: 系统分发延迟-警告阈值（ms）
- name: binder_blocking_threshold_ms
  type: number
  required: false
  default: 30
  description: Binder 阻塞判定阈值（ms）
- name: critical_event_threshold_ms
  type: number
  required: false
  default: 200
  description: 严重慢事件阈值（ms）
- name: thread_state_min_dur_ms
  type: number
  required: false
  default: 50
  description: 线程状态分析最小输入延迟阈值（ms）
- name: enable_per_event_detail
  type: boolean
  required: false
  default: true
  description: 是否启用逐事件详细分析（策略模式可关闭以避免重复）
```

## Ordered execution

### 检查输入事件数据

- ID: `check_input_data`
- Type: `atomic`
- SQL: [`../sql/click_response_analysis/check_input_data.sql`](../sql/click_response_analysis/check_input_data.sql)

```yaml
id: check_input_data
type: atomic
optional: true
display:
  level: summary
  layer: overview
  title: 数据检查
  columns:
  - name: event_count
    label: 事件数
    type: number
    format: compact
  - name: status
    label: 状态
    type: string
save_as: input_check
```
### 选择目标进程

- ID: `get_process`
- Type: `atomic`
- SQL: [`../sql/click_response_analysis/get_process.sql`](../sql/click_response_analysis/get_process.sql)

```yaml
id: get_process
type: atomic
display:
  level: summary
  layer: overview
  title: 目标进程
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: event_count
    label: 事件数
    type: number
    format: compact
  - name: max_total_ms
    label: 最大延迟
    type: duration
    format: duration_ms
    unit: ms
save_as: target_process
condition: input_check.data[0]?.status === 'available'
```
### 输入延迟概览

- ID: `input_latency_overview`
- Type: `atomic`
- SQL: [`../sql/click_response_analysis/input_latency_overview.sql`](../sql/click_response_analysis/input_latency_overview.sql)

```yaml
id: input_latency_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: total_events
    label: 事件总数
  - key: avg_total_ms
    label: 平均延迟
    format: '{{value}} ms'
  - key: max_total_ms
    label: 最大延迟
    format: '{{value}} ms'
  - key: rating
    label: 评级
  insights:
  - condition: avg_total_ms > 100
    template: 平均输入延迟 {{avg_total_ms}}ms，超过 100ms 需优化
  - condition: avg_handling_ms > avg_dispatch_ms
    template: 应用处理延迟 ({{avg_handling_ms}}ms) 高于系统分发 ({{avg_dispatch_ms}}ms)
display:
  level: key
  layer: overview
  title: 输入延迟概览
  columns:
  - name: total_events
    label: 事件总数
    type: number
    format: compact
  - name: avg_dispatch_ms
    label: 平均分发延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: max_dispatch_ms
    label: 最大分发延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_handling_ms
    label: 平均处理延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: max_handling_ms
    label: 最大处理延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_ack_ms
    label: 平均 ACK 延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_total_ms
    label: 平均总延迟(ACK)
    type: duration
    format: duration_ms
    unit: ms
  - name: max_total_ms
    label: 最大总延迟(ACK)
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_e2e_ms
    label: 平均 Input→Frame 延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: max_e2e_ms
    label: 最大 Input→Frame 延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: rating
    label: 评级
    type: string
save_as: latency_overview
condition: input_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 按事件类型分析

- ID: `latency_by_event_type`
- Type: `atomic`
- SQL: [`../sql/click_response_analysis/latency_by_event_type.sql`](../sql/click_response_analysis/latency_by_event_type.sql)

```yaml
id: latency_by_event_type
type: atomic
synthesize:
  role: list
  groupBy:
  - field: event_type
    title: 按事件类型分布
  fields:
  - key: event_action
    label: 事件动作
  - key: avg_latency_ms
    label: 平均延迟
    format: '{{value}} ms'
  - key: slow_events
    label: 慢事件数
display:
  level: key
  layer: overview
  title: 各事件类型延迟
  columns:
  - name: event_type
    label: 事件类型
    type: string
  - name: event_action
    label: 事件动作
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: avg_latency_ms
    label: 平均延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: max_latency_ms
    label: 最大延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_handling_ms
    label: 平均处理延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: slow_events
    label: 慢事件数
    type: number
save_as: latency_by_type
condition: input_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 按窗口分析

- ID: `latency_by_window`
- Type: `atomic`
- SQL: [`../sql/click_response_analysis/latency_by_window.sql`](../sql/click_response_analysis/latency_by_window.sql)

```yaml
id: latency_by_window
type: atomic
optional: true
synthesize:
  role: list
  groupBy:
  - field: window
    title: 按目标窗口分布
  fields:
  - key: avg_latency_ms
    label: 平均延迟
    format: '{{value}} ms'
  - key: slow_events
    label: 慢事件数
display:
  level: key
  layer: overview
  title: 各窗口延迟
  columns:
  - name: window
    label: 窗口
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: avg_latency_ms
    label: 平均延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: max_latency_ms
    label: 最大延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_handling_ms
    label: 平均处理延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: slow_events
    label: 慢事件数
    type: number
save_as: latency_by_window
condition: input_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 慢输入事件

- ID: `slow_input_events`
- Type: `atomic`
- SQL: [`../sql/click_response_analysis/slow_input_events.sql`](../sql/click_response_analysis/slow_input_events.sql)

```yaml
id: slow_input_events
type: atomic
synthesize:
  role: list
  groupBy:
  - field: main_bottleneck
    title: 按延迟来源分布
  - field: severity
    title: 按严重程度分布
  fields:
  - key: event_type
    label: 事件类型
  - key: total_ms
    label: 总延迟
    format: '{{value}} ms'
  - key: main_bottleneck
    label: 瓶颈
display:
  level: key
  layer: list
  title: 慢输入事件详情 (>100ms)
  columns:
  - name: event_type
    label: 事件类型
    type: string
  - name: event_action
    label: 事件动作
    type: string
  - name: event_channel
    label: 事件通道
    type: string
  - name: normalized_channel
    label: 窗口
    type: string
  - name: total_ms
    label: 总延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: dispatch_ms
    label: 分发延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: handling_ms
    label: 处理延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: ack_ms
    label: ACK 延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: e2e_ms
    label: Input→Frame 延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: thread_name
    label: 线程
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: frame_id
    label: 帧 ID
    type: number
  - name: event_ts
    label: 事件时间
    type: timestamp
    clickAction: navigate_range
    durationColumn: total_ms
  - name: event_end_ts
    label: 结束时间
    type: timestamp
    clickAction: navigate_timeline
    hidden: true
  - name: perfetto_start
    label: Perfetto 开始
    type: timestamp
    clickAction: navigate_timeline
    hidden: true
  - name: perfetto_end
    label: Perfetto 结束
    type: timestamp
    clickAction: navigate_timeline
    hidden: true
  - name: severity
    label: 严重程度
    type: enum
  - name: main_bottleneck
    label: 主要瓶颈
    type: string
save_as: slow_events
condition: input_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 输入期间主线程状态

- ID: `input_thread_state`
- Type: `atomic`
- SQL: [`../sql/click_response_analysis/input_thread_state.sql`](../sql/click_response_analysis/input_thread_state.sql)

```yaml
id: input_thread_state
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 输入处理期间主线程状态
  columns:
  - name: event_type
    label: 事件类型
    type: string
  - name: input_dur_ms
    label: 输入延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: state
    label: 线程状态
    type: string
  - name: state_dur_ms
    label: 状态持续时间
    type: duration
    format: duration_ms
    unit: ms
  - name: blocked_function
    label: 阻塞函数
    type: string
save_as: input_thread_state
condition: input_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 输入期间 Binder

- ID: `input_binder_calls`
- Type: `atomic`
- SQL: [`../sql/click_response_analysis/input_binder_calls.sql`](../sql/click_response_analysis/input_binder_calls.sql)

```yaml
id: input_binder_calls
type: atomic
display:
  level: detail
  layer: list
  title: 输入处理期间 Binder 调用
  columns:
  - name: server_process
    label: 服务进程
    type: string
  - name: aidl_name
    label: AIDL 方法
    type: string
  - name: call_count
    label: 调用次数
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
  - name: main_thread_calls
    label: 主线程调用
    type: number
save_as: input_binder
condition: input_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 输入到帧关联

- ID: `input_to_frame`
- Type: `atomic`
- SQL: [`../sql/click_response_analysis/input_to_frame.sql`](../sql/click_response_analysis/input_to_frame.sql)

```yaml
id: input_to_frame
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 输入到帧渲染延迟
  columns:
  - name: event_type
    label: 事件类型
    type: string
  - name: event_action
    label: 事件动作
    type: string
  - name: e2e_latency_ms
    label: Input→Frame 延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: frame_id
    label: 帧 ID
    type: number
  - name: frame_dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: input_latency_ms
    label: Input ACK 延迟
    type: duration
    format: duration_ms
    unit: ms
  - name: rating
    label: 评级
    type: enum
save_as: input_to_frame
condition: input_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 延迟分布

- ID: `latency_distribution`
- Type: `atomic`
- SQL: [`../sql/click_response_analysis/latency_distribution.sql`](../sql/click_response_analysis/latency_distribution.sql)

```yaml
id: latency_distribution
type: atomic
synthesize:
  role: overview
  fields:
  - key: latency_bucket
    label: 延迟区间
  - key: count
    label: 事件数
  - key: percent
    label: 占比
    format: '{{value}}%'
display:
  level: summary
  layer: overview
  title: 输入延迟分布
  columns:
  - name: latency_bucket
    label: 延迟区间
    type: string
  - name: count
    label: 事件数
    type: number
    format: compact
  - name: percent
    label: 占比
    type: percentage
    format: percentage
save_as: latency_distribution
condition: input_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 慢输入事件详细分析

- ID: `analyze_slow_events`
- Type: `iterator`

```yaml
id: analyze_slow_events
type: iterator
synthesize:
  role: clusters
  clusterBy: main_bottleneck
display:
  level: key
  layer: deep
  title: 慢输入事件详细分析
source: slow_events
item_skill: click_response_detail
item_params:
  event_ts: event_ts
  event_end_ts: event_end_ts
  total_ms: total_ms
  dispatch_ms: dispatch_ms
  handling_ms: handling_ms
  event_type: event_type
  event_action: event_action
  process_name: process_name
  perfetto_start: perfetto_start
  perfetto_end: perfetto_end
condition: slow_events.data.length > 0 && '${enable_per_event_detail|true}' !== 'false'
```
### 点击响应诊断

- ID: `click_diagnosis`
- Type: `diagnostic`

```yaml
id: click_diagnosis
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
  - template: 点击响应诊断：{{diagnosis}}
display:
  level: key
  layer: overview
  title: 问题诊断
inputs:
- latency_overview
- slow_events
- input_thread_state
- input_binder
rules:
- condition: latency_overview.data[0]?.avg_total_ms > ${avg_latency_critical_ms|100}
  severity: critical
  diagnosis: 平均输入延迟过高 (${latency_overview.data[0].avg_total_ms}ms)
  confidence: high
  suggestions:
  - 检查主线程是否有耗时操作
  - 优化事件处理逻辑
  - 将耗时操作移到后台线程
- condition: latency_overview.data[0]?.avg_handling_ms > ${avg_handling_warning_ms|50}
  severity: warning
  diagnosis: 应用处理延迟偏高 (${latency_overview.data[0].avg_handling_ms}ms)
  confidence: high
  suggestions:
  - 优化 onClick/onTouchEvent 处理
  - 避免在事件处理中进行 IO 操作
- condition: latency_overview.data[0]?.avg_dispatch_ms > ${avg_dispatch_warning_ms|20}
  severity: warning
  diagnosis: 系统分发延迟偏高 (${latency_overview.data[0].avg_dispatch_ms}ms)
  confidence: medium
  suggestions:
  - 可能是系统负载过高
  - 检查输入系统是否有瓶颈
- condition: slow_events.data[0]?.total_ms > ${critical_event_threshold_ms|200}
  severity: critical
  diagnosis: 存在严重慢输入事件 (${slow_events.data[0].total_ms}ms)
  confidence: high
  suggestions:
  - 分析该事件期间主线程状态
  - 检查是否有 Binder/IO 阻塞
- condition: input_binder.data[0]?.total_dur_ms > ${binder_blocking_threshold_ms|30}
  severity: warning
  diagnosis: 输入期间存在 Binder 阻塞 (${input_binder.data[0].total_dur_ms}ms)
  confidence: high
  suggestions:
  - 将 Binder 调用移到后台线程
  - 使用异步 Binder 接口
```
## Output and evidence contract

```yaml
format: structured
```
