GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/scene_reconstruction.skill.yaml
Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
# 场景还原

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: scene_reconstruction
version: '1.0'
type: composite
category: interaction
tier: S
```

## Metadata

```yaml
display_name: 场景还原
description: 通过用户输入和屏幕状态还原用户操作场景
icon: movie_creation
tags:
- scene
- input
- screen
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 场景还原
  - 还原场景
  - 发生了什么
  - 用户操作
  - 操作场景
  - 用户行为
  - 操作记录
  en:
  - scene
  - reconstruct
  - what happened
  - user action
  - user behavior
patterns:
- .*场景.*还原.*
- .*发生.*什么.*
- .*用户.*操作.*
```

## Prerequisites

```yaml
modules:
- android.input
- android.binder
- android.screen_state
- android.battery_stats
- android.startup.startups
- android.frames.timeline
- android.anrs
```

## Inputs

```yaml
- name: trace_id
  type: string
  required: true
```

## Ordered execution

### Trace 时间范围

- ID: `trace_time_range`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/trace_time_range.sql`](../sql/scene_reconstruction/trace_time_range.sql)

```yaml
id: trace_time_range
type: atomic
display:
  level: summary
  layer: overview
  title: Trace 概览
  columns:
  - name: start_ts_str
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: end_ts_str
    label: 结束时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: duration_sec
    label: 时长(秒)
    type: number
save_as: time_range
```
### 可用数据表探测

- ID: `table_availability`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/table_availability.sql`](../sql/scene_reconstruction/table_availability.sql)

```yaml
id: table_availability
type: atomic
display:
  level: hidden
save_as: table_availability
```
### 屏幕状态变化

- ID: `screen_state_changes`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/screen_state_changes.sql`](../sql/scene_reconstruction/screen_state_changes.sql)

```yaml
id: screen_state_changes
type: atomic
condition: table_availability.data[0]?.has_screen_state === 1
display:
  level: hidden
  layer: list
  title: 屏幕状态
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 状态
    type: string
  - name: category
    label: 类别
    type: string
save_as: screen_events
optional: true
```
### Top App 切换

- ID: `top_app_changes`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/top_app_changes.sql`](../sql/scene_reconstruction/top_app_changes.sql)

```yaml
id: top_app_changes
type: atomic
condition: table_availability.data[0]?.has_battery_top === 1
display:
  level: hidden
  layer: list
  title: 应用切换
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: app_package
    label: 包名
    type: string
  - name: category
    label: 类别
    type: string
save_as: app_switches
optional: true
```
### Activity 生命周期

- ID: `activity_lifecycle`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/activity_lifecycle.sql`](../sql/scene_reconstruction/activity_lifecycle.sql)

```yaml
id: activity_lifecycle
type: atomic
display:
  level: hidden
  layer: list
  title: Activity 生命周期
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: activity_name
    label: Activity
    type: string
  - name: lifecycle_event
    label: 生命周期事件
    type: string
  - name: dur_ms
    label: 耗时(ms)
    type: number
save_as: activity_lifecycle
optional: true
```
### 用户手势识别

- ID: `user_gestures`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/user_gestures.sql`](../sql/scene_reconstruction/user_gestures.sql)

```yaml
id: user_gestures
type: atomic
condition: table_availability.data[0]?.has_input_events === 1 && table_availability.data[0]?.has_startups === 1 && table_availability.data[0]?.has_frame_timeline
  === 1
display:
  level: hidden
  layer: list
  title: 用户操作
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 操作
    type: string
  - name: gesture_type
    label: 类型
    type: string
  - name: confidence
    label: 置信度
    type: string
  - name: move_count
    label: 移动次数
    type: number
  - name: app_package
    label: 应用
    type: string
  - name: category
    label: 类别
    type: string
save_as: gestures
optional: true
```
### 滑动启动时刻

- ID: `scroll_initiation`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/scroll_initiation.sql`](../sql/scene_reconstruction/scroll_initiation.sql)

```yaml
id: scroll_initiation
type: atomic
condition: table_availability.data[0]?.has_input_events === 1
display:
  level: hidden
  layer: list
  title: 滑动启动
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: event
    label: 事件
    type: string
  - name: gesture_id
    label: 手势ID
    type: number
  - name: app_package
    label: 前台应用
    type: string
  - name: category
    label: 类别
    type: string
  - name: explanation
    label: 说明
    type: string
save_as: scroll_starts
optional: true
```
### 导航按键

- ID: `navigation_keys`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/navigation_keys.sql`](../sql/scene_reconstruction/navigation_keys.sql)

```yaml
id: navigation_keys
type: atomic
condition: table_availability.data[0]?.has_key_events === 1
display:
  level: hidden
  layer: list
  title: 导航按键
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: key_name
    label: 按键
    type: string
  - name: category
    label: 类别
    type: string
save_as: nav_keys
optional: true
```
### 手势导航

- ID: `gesture_navigation`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/gesture_navigation.sql`](../sql/scene_reconstruction/gesture_navigation.sql)

```yaml
id: gesture_navigation
type: atomic
display:
  level: hidden
  layer: list
  title: 手势导航
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: key_name
    label: 类型
    type: string
  - name: category
    label: 类别
    type: string
save_as: gesture_nav
optional: true
```
### 窗口转场

- ID: `window_transitions`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/window_transitions.sql`](../sql/scene_reconstruction/window_transitions.sql)

```yaml
id: window_transitions
type: atomic
display:
  level: hidden
  layer: list
  title: 窗口转场
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: transition_type
    label: 转场类型
    type: string
  - name: category
    label: 类别
    type: string
save_as: win_transitions
optional: true
```
### ANR 事件

- ID: `anr_events`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/anr_events.sql`](../sql/scene_reconstruction/anr_events.sql)

```yaml
id: anr_events
type: atomic
condition: table_availability.data[0]?.has_anrs === 1
display:
  level: hidden
  layer: list
  title: ANR 事件
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: anr_type
    label: ANR类型
    type: string
  - name: category
    label: 类别
    type: string
save_as: anr_events
optional: true
```
### 输入法事件

- ID: `ime_events`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/ime_events.sql`](../sql/scene_reconstruction/ime_events.sql)

```yaml
id: ime_events
type: atomic
display:
  level: hidden
  layer: list
  title: 输入法
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: ime_action
    label: 操作
    type: string
  - name: category
    label: 类别
    type: string
save_as: ime_events
optional: true
```
### 惯性滑动

- ID: `inertial_scrolls`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/inertial_scrolls.sql`](../sql/scene_reconstruction/inertial_scrolls.sql)

```yaml
id: inertial_scrolls
type: atomic
condition: table_availability.data[0]?.has_input_events === 1 && table_availability.data[0]?.has_frame_timeline === 1
display:
  level: hidden
  layer: list
  title: 惯性滑动
  columns:
  - name: ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: frame_count
    label: 帧数
    type: number
  - name: jank_frames
    label: 掉帧数
    type: number
  - name: app_package
    label: 应用
    type: string
  - name: category
    label: 类别
    type: string
save_as: inertial_scrolls
optional: true
```
### Idle 区间

- ID: `idle_periods`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/idle_periods.sql`](../sql/scene_reconstruction/idle_periods.sql)

```yaml
id: idle_periods
type: atomic
condition: table_availability.data[0]?.has_input_events === 1 && table_availability.data[0]?.has_startups === 1
display:
  level: hidden
  layer: list
  title: 空闲区间
  columns:
  - name: ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: confidence
    label: 置信度
    type: string
  - name: category
    label: 类别
    type: string
save_as: idle_periods
optional: true
```
### App 启动事件

- ID: `app_launches`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/app_launches.sql`](../sql/scene_reconstruction/app_launches.sql)

```yaml
id: app_launches
type: atomic
condition: table_availability.data[0]?.has_startups === 1
display:
  level: hidden
  layer: list
  title: App 启动
  columns:
  - name: startup_id
    label: ID
    type: number
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: startup_type
    label: 类型
    type: string
  - name: package
    label: 包名
    type: string
  - name: category
    label: 类别
    type: string
save_as: launches
optional: true
```
### 系统事件

- ID: `system_events`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/system_events.sql`](../sql/scene_reconstruction/system_events.sql)

```yaml
id: system_events
type: atomic
display:
  level: hidden
  layer: list
  title: 系统事件
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: event_type
    label: 类型
    type: string
  - name: category
    label: 类别
    type: string
save_as: sys_events
optional: true
```
### 广播事件

- ID: `broadcast_events`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/broadcast_events.sql`](../sql/scene_reconstruction/broadcast_events.sql)

```yaml
id: broadcast_events
type: atomic
display:
  level: hidden
  layer: list
  title: 广播事件
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: receiver_name
    label: 接收者
    type: string
  - name: broadcast_action
    label: 广播类型
    type: string
  - name: dur_ms
    label: 耗时(ms)
    type: number
save_as: broadcast_events
optional: true
```
### 跨进程交互

- ID: `cross_process_interactions`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/cross_process_interactions.sql`](../sql/scene_reconstruction/cross_process_interactions.sql)

```yaml
id: cross_process_interactions
type: atomic
display:
  level: hidden
  layer: list
  title: 跨进程交互
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: client_process
    label: 客户端进程
    type: string
  - name: server_process
    label: 服务端进程
    type: string
  - name: dur_ms
    label: 耗时(ms)
    type: number
  - name: interface_name
    label: 接口名
    type: string
save_as: cross_process_interactions
optional: true
```
### 掉帧事件

- ID: `jank_events`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/jank_events.sql`](../sql/scene_reconstruction/jank_events.sql)

```yaml
id: jank_events
type: atomic
condition: table_availability.data[0]?.has_frame_timeline === 1
display:
  level: hidden
  layer: list
  title: 性能事件
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur
    label: 帧耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: event
    label: 事件
    type: string
  - name: jank_type
    label: 掉帧类型
    type: string
  - name: jank_severity_type
    label: 严重程度
    type: string
  - name: category
    label: 类别
    type: string
save_as: janks
optional: true
```
### 设备状态

- ID: `device_state`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/device_state.sql`](../sql/scene_reconstruction/device_state.sql)

```yaml
id: device_state
type: atomic
display:
  level: detail
  layer: list
  title: 设备状态
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: event
    label: 状态
    type: string
  - name: value
    label: 值
    type: string
  - name: category
    label: 类别
    type: string
save_as: device_state
optional: true
```
### App 状态跟踪

- ID: `app_state_tracking`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/app_state_tracking.sql`](../sql/scene_reconstruction/app_state_tracking.sql)

```yaml
id: app_state_tracking
type: atomic
display:
  level: detail
  layer: list
  title: App 前后台状态
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: event
    label: 事件
    type: string
  - name: app_package
    label: 应用
    type: string
  - name: oom_adj
    label: oom_adj
    type: number
  - name: state_label
    label: 状态
    type: string
  - name: category
    label: 类别
    type: string
save_as: app_states
optional: true
```
### 操作链

- ID: `operation_chain`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/operation_chain.sql`](../sql/scene_reconstruction/operation_chain.sql)

```yaml
id: operation_chain
type: atomic
display:
  level: hidden
  layer: list
  title: 操作链
  columns:
  - name: time_offset
    label: 时间偏移
    type: string
  - name: ts
    label: 时间戳
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: event
    label: 事件
    type: string
  - name: category
    label: 类别
    type: string
  - name: priority
    label: 优先级
    type: number
save_as: operation_chain
optional: true
```
### 场景时间线

- ID: `clean_timeline`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/clean_timeline.sql`](../sql/scene_reconstruction/clean_timeline.sql)

```yaml
id: clean_timeline
type: atomic
condition: table_availability.data[0]?.has_input_events === 1 || table_availability.data[0]?.has_startups === 1 || table_availability.data[0]?.has_key_events
  === 1 || table_availability.data[0]?.has_anrs === 1
display:
  level: detail
  layer: list
  title: 场景时间线
  columns:
  - name: event_id
    label: ID
    type: string
    hidden: true
  - name: time_offset
    label: 时间
    type: string
  - name: ts
    label: 时间戳
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
    hidden: true
  - name: dur_ms
    label: 耗时(ms)
    type: number
  - name: event_type
    label: 类型
    type: string
    hidden: true
  - name: event
    label: 事件
    type: string
  - name: app_package
    label: 应用
    type: string
  - name: rating
    label: 评级
    type: string
save_as: clean_timeline
optional: true
```
### 合并时间线

- ID: `merged_timeline`
- Type: `atomic`
- SQL: [`../sql/scene_reconstruction/merged_timeline.sql`](../sql/scene_reconstruction/merged_timeline.sql)

```yaml
id: merged_timeline
type: atomic
condition: table_availability.data[0]?.has_screen_state === 1 || table_availability.data[0]?.has_input_events === 1 || table_availability.data[0]?.has_startups
  === 1 || table_availability.data[0]?.has_frame_timeline === 1
display:
  level: hidden
  layer: list
  title: 操作时间线
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur
  - name: dur
    label: 持续
    type: duration
    format: duration_ms
    unit: ns
  - name: time_offset_sec
    label: 时间偏移(s)
    type: number
  - name: event
    label: 事件
    type: string
  - name: category
    label: 类别
    type: string
  - name: priority
    label: 优先级
    type: number
save_as: timeline
optional: true
```
### 场景还原报告

- ID: `scene_summary`
- Type: `ai_summary`

```yaml
id: scene_summary
type: ai_summary
display:
  level: summary
  layer: overview
  title: 场景还原报告
inputs:
- trace_time_range
- clean_timeline
- screen_state_changes
- top_app_changes
- user_gestures
- scroll_initiation
- inertial_scrolls
- idle_periods
- app_launches
- system_events
- jank_events
- device_state
- app_state_tracking
- operation_chain
prompt: '你是一位 Android 性能分析专家，你的任务是帮助初学者理解 Trace 数据。

  请基于以下数据还原用户的完整操作场景，并用通俗易懂的语言解释。


  ## Trace 时间范围

  ${trace_time_range}


  ## 干净时间线（主要参考）

  ${clean_timeline}

  说明：这是经过质量过滤的事件时间线，请优先参考此数据构建叙述


  ## 屏幕状态变化

  ${screen_state_changes}


  ## 应用切换记录

  ${top_app_changes}


  ## 用户手势操作

  ${user_gestures}


  ## 滑动启动时刻

  ${scroll_initiation}

  说明：这里记录了每次滑动开始的精确时刻（手指按下后移动到第2个点时）


  ## 惯性滑动区间

  ${inertial_scrolls}

  说明：这里记录手指抬起（UP）后界面仍在滚动的区间，通常对应 Fling 惯性滚动


  ## 空闲区间（Idle）

  ${idle_periods}

  说明：这里记录较长时间没有明显用户交互/切换的区间


  ## App 启动事件

  ${app_launches}


  ## 系统事件

  ${system_events}


  ## 掉帧/性能事件

  ${jank_events}


  ## 设备状态

  ${device_state}

  说明：设备硬件状态快照，包括 CPU 频率范围、内存压力、温度、充电状态和前台应用


  ## App 前后台状态变化

  ${app_state_tracking}

  说明：应用的 oom_adj 变化记录，反映前台/可见/后台/缓存状态转换和进程创建事件


  ## 操作链

  ${operation_chain}

  说明：按时间顺序排列的所有用户可感知事件，用于构建完整操作时间线


  请按以下格式输出分析报告：


  ## 场景概述

  用一段自然、流畅的中文描述用户在这段 Trace 期间做了什么。描述应该像讲故事一样，让读者能够清晰地想象用户的操作过程。


  ## 操作时间线

  按时间顺序列出关键操作，格式：

  1. **0.0s** - 事件描述

  2. **1.2s** - 事件描述

  ...

  （请合并相近的同类事件，避免过于琐碎）


  ## 性能问题诊断

  如果发现掉帧或性能问题，请分析：

  - 问题发生在什么场景下

  - 可能的原因是什么

  - 对用户体验的影响


  如果没有明显性能问题，请说明"整体流畅度良好"。


  ## 使用意图推断

  基于以上分析，推断用户可能的使用意图和目的。例如：

  - 用户可能在浏览社交媒体

  - 用户可能在查找某个联系人

  - 用户可能在切换应用完成某个任务

  '
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- L1
- L2
```
