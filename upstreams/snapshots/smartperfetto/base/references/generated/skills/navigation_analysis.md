GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/navigation_analysis.skill.yaml
Source SHA-256: 1ebfd2d987dc15689b41fd76a43570d53d80c2054b688b131b355b37c3585b99
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# 界面跳转分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: navigation_analysis
version: '3.0'
type: composite
tier: S
```

## Metadata

```yaml
display_name: 界面跳转分析
description: 分析 Activity/Fragment 跳转性能、生命周期耗时、主线程阻塞
icon: arrows-alt
tags:
- navigation
- activity
- fragment
- transition
- lifecycle
```

## Triggers

```yaml
keywords:
  zh:
  - 界面跳转
  - 页面切换
  - Activity跳转
  - Fragment切换
  - 跳转慢
  - 切换卡顿
  - 页面加载
  - 跳转耗时
  en:
  - navigation
  - page transition
  - activity transition
  - fragment transition
  - slow navigation
patterns:
- .*跳转.*慢.*
- .*切换.*卡.*
- .*页面.*加载.*
- .*activity.*transition.*
- .*navigation.*slow.*
```

## Prerequisites

```yaml
modules:
- android.binder
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
- name: slow_navigation_ms
  type: number
  required: false
  default: 400
  description: 慢跳转判定阈值（ms）
- name: nav_rating_good_ms
  type: number
  required: false
  default: 200
  description: 跳转评级-优秀阈值（ms）
- name: nav_rating_severe_ms
  type: number
  required: false
  default: 700
  description: 跳转评级-严重阈值（ms）
- name: slow_lifecycle_ms
  type: number
  required: false
  default: 100
  description: 慢生命周期事件阈值（ms）
- name: blocking_op_min_dur_ms
  type: number
  required: false
  default: 5
  description: 阻塞操作最小显示阈值（ms）
- name: inflate_critical_ms
  type: number
  required: false
  default: 100
  description: 布局膨胀严重阈值（ms）
- name: binder_blocking_ms
  type: number
  required: false
  default: 16
  description: Binder 阻塞判定阈值（ms）
- name: oncreate_slow_ms
  type: number
  required: false
  default: 200
  description: onCreate 过慢阈值（ms）
```

## Ordered execution

### 检查生命周期数据

- ID: `check_lifecycle_data`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/check_lifecycle_data.sql`](../sql/navigation_analysis/check_lifecycle_data.sql)

```yaml
id: check_lifecycle_data
type: atomic
display: false
save_as: lifecycle_check
```
### 选择目标进程

- ID: `get_process`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/get_process.sql`](../sql/navigation_analysis/get_process.sql)

```yaml
id: get_process
type: atomic
display: false
save_as: target_process
condition: lifecycle_check.data[0]?.status === 'available'
```
### 跳转概览

- ID: `navigation_overview`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/navigation_overview.sql`](../sql/navigation_analysis/navigation_overview.sql)

```yaml
id: navigation_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: total_navigations
    label: 跳转总数
  - key: avg_nav_dur_ms
    label: 平均跳转耗时
    format: '{{value}} ms'
  - key: max_nav_dur_ms
    label: 最慢跳转耗时
    format: '{{value}} ms'
  - key: rating
    label: 评级
  insights:
  - condition: avg_nav_dur_ms > 400
    template: 平均跳转耗时 {{avg_nav_dur_ms}}ms，超过 400ms 需优化
  - condition: max_nav_dur_ms > 700
    template: 最慢跳转耗时 {{max_nav_dur_ms}}ms，严重影响体验
display:
  level: key
  layer: overview
  title: 界面跳转概览
  columns:
  - name: total_navigations
    label: 跳转总数
    type: number
    format: compact
  - name: avg_nav_dur_ms
    label: 平均跳转耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_nav_dur_ms
    label: 最慢跳转耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: total_lifecycle_events
    label: 生命周期事件数
    type: number
    format: compact
  - name: slow_navigations
    label: 慢跳转 (>400ms)
    type: number
  - name: rating
    label: 评级
    type: string
save_as: nav_overview
condition: lifecycle_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 生命周期阶段耗时

- ID: `lifecycle_phase_breakdown`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/lifecycle_phase_breakdown.sql`](../sql/navigation_analysis/lifecycle_phase_breakdown.sql)

```yaml
id: lifecycle_phase_breakdown
type: atomic
synthesize:
  role: overview
  fields:
  - key: phase
    label: 生命周期阶段
  - key: avg_dur_ms
    label: 平均耗时
    format: '{{value}} ms'
  - key: total_count
    label: 次数
display:
  level: key
  layer: overview
  title: Activity 生命周期阶段耗时
  columns:
  - name: phase
    label: 生命周期阶段
    type: string
  - name: total_count
    label: 次数
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
  - name: slow_count
    label: 慢事件 (>100ms)
    type: number
save_as: lifecycle_phases
condition: lifecycle_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 生命周期事件详情

- ID: `lifecycle_event_detail`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/lifecycle_event_detail.sql`](../sql/navigation_analysis/lifecycle_event_detail.sql)

```yaml
id: lifecycle_event_detail
type: atomic
synthesize:
  role: list
  groupBy:
  - field: phase
    title: 按生命周期阶段分布
  fields:
  - key: event_name
    label: 事件名称
  - key: dur_ms
    label: 耗时
    format: '{{value}} ms'
  - key: phase
    label: 阶段
display:
  level: key
  layer: list
  title: Activity 生命周期事件详情
  columns:
  - name: event_ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: event_name
    label: 事件名称
    type: string
  - name: phase
    label: 阶段
    type: string
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
  - name: severity
    label: 严重程度
    type: enum
save_as: lifecycle_detail
condition: lifecycle_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 跳转期间主线程阻塞

- ID: `navigation_blocking_ops`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/navigation_blocking_ops.sql`](../sql/navigation_analysis/navigation_blocking_ops.sql)

```yaml
id: navigation_blocking_ops
type: atomic
synthesize:
  role: list
  groupBy:
  - field: block_type
    title: 按阻塞类型分布
  fields:
  - key: blocking_op
    label: 阻塞操作
  - key: dur_ms
    label: 耗时
    format: '{{value}} ms'
  - key: block_type
    label: 类型
display:
  level: key
  layer: list
  title: 跳转期间主线程阻塞操作 (>5ms)
  columns:
  - name: block_ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: blocking_op
    label: 操作名称
    type: string
  - name: block_type
    label: 类型
    type: string
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
  - name: severity
    label: 严重程度
    type: enum
save_as: blocking_ops
condition: lifecycle_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 布局膨胀分析

- ID: `layout_inflation`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/layout_inflation.sql`](../sql/navigation_analysis/layout_inflation.sql)

```yaml
id: layout_inflation
type: atomic
display:
  level: key
  layer: list
  title: 布局膨胀耗时 (>1ms)
  columns:
  - name: inflate_ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: layout_event
    label: 布局事件
    type: string
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
save_as: layout_inflation
condition: lifecycle_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### Fragment 事务分析

- ID: `fragment_transactions`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/fragment_transactions.sql`](../sql/navigation_analysis/fragment_transactions.sql)

```yaml
id: fragment_transactions
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: Fragment 事务
  columns:
  - name: frag_ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: fragment_event
    label: 事件名称
    type: string
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
save_as: fragment_txns
condition: lifecycle_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 转场动画分析

- ID: `transition_animations`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/transition_animations.sql`](../sql/navigation_analysis/transition_animations.sql)

```yaml
id: transition_animations
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 转场动画
  columns:
  - name: anim_ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: animation_event
    label: 动画事件
    type: string
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
save_as: transition_anims
condition: lifecycle_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 跳转期间 Binder 调用

- ID: `navigation_binder_calls`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/navigation_binder_calls.sql`](../sql/navigation_analysis/navigation_binder_calls.sql)

```yaml
id: navigation_binder_calls
type: atomic
optional: true
display:
  level: key
  layer: list
  title: 跳转期间 Binder 调用
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
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: main_thread_calls
    label: 主线程调用
    type: number
save_as: nav_binder
condition: lifecycle_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 首帧渲染分析

- ID: `first_frame_render`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/first_frame_render.sql`](../sql/navigation_analysis/first_frame_render.sql)

```yaml
id: first_frame_render
type: atomic
display:
  level: detail
  layer: list
  title: Choreographer doFrame 事件
  columns:
  - name: frame_ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 耗时
    type: duration
    format: duration_ms
    unit: ns
  - name: frame_event
    label: 事件名称
    type: string
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
    hidden: true
save_as: first_frames
condition: lifecycle_check.data[0]?.status === 'available' && target_process.data.length > 0
```
### 跳转诊断

- ID: `navigation_diagnosis`
- Type: `diagnostic`

```yaml
id: navigation_diagnosis
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
  - template: 界面跳转诊断：{{diagnosis}}
display:
  level: key
  layer: overview
  title: 问题诊断
inputs:
- nav_overview
- lifecycle_phases
- blocking_ops
- layout_inflation
- nav_binder
rules:
- condition: (layout_inflation?.data?.length || 0) > 0 && layout_inflation.data[0]?.dur_ms > ${inflate_critical_ms|100}
  severity: critical
  diagnosis: 'SLOW_INFLATE: 布局膨胀严重 (${layout_inflation.data[0].dur_ms}ms)，是跳转耗时主因'
  confidence: high
  suggestions:
  - 减少布局嵌套层级，使用 ConstraintLayout
  - 使用 ViewStub 延迟加载非首屏布局
  - 考虑使用异步布局膨胀 (AsyncLayoutInflater)
- condition: (nav_binder?.data?.length || 0) > 0 && nav_binder.data[0]?.max_dur_ms > ${binder_blocking_ms|16} && nav_binder.data[0]?.main_thread_calls
    > 0
  severity: warning
  diagnosis: 'SLOW_BINDER: 跳转期间主线程 Binder 阻塞 (最大 ${nav_binder.data[0].max_dur_ms}ms)'
  confidence: high
  suggestions:
  - 将 Binder 调用移到后台线程
  - 使用异步 Binder 接口
  - 缓存服务调用结果
- condition: (blocking_ops?.data?.length || 0) > 0 && blocking_ops.data.find(b => b.block_type === 'file_io' || b.block_type
    === 'database' || b.block_type === 'shared_prefs')?.dur_ms > ${binder_blocking_ms|16}
  severity: warning
  diagnosis: 'SLOW_IO: 跳转期间存在 IO 阻塞 (${blocking_ops.data.find(b => b.block_type === ''file_io'' || b.block_type === ''database''
    || b.block_type === ''shared_prefs'')?.dur_ms}ms)'
  confidence: high
  suggestions:
  - 将 IO 操作移到后台线程
  - 使用 ViewModel 预加载数据
  - 使用内存缓存减少磁盘读取
- condition: (lifecycle_phases?.data?.length || 0) > 0 && (lifecycle_phases.data.find(p => p.phase === 'onCreate')?.max_dur_ms
    || 0) > ${oncreate_slow_ms|200}
  severity: warning
  diagnosis: 'SLOW_ONCREATE: Activity onCreate 耗时过长 (${lifecycle_phases.data.find(p => p.phase === ''onCreate'')?.max_dur_ms}ms)'
  confidence: medium
  suggestions:
  - 延迟初始化非必要组件
  - 将数据加载移到后台线程
  - 使用 Jetpack App Startup 优化初始化顺序
- condition: (nav_overview?.data?.[0]?.avg_nav_dur_ms || 0) <= ${slow_navigation_ms|400}
  severity: info
  diagnosis: 'NAVIGATION_NORMAL: 跳转性能正常 (平均 ${nav_overview?.data?.[0]?.avg_nav_dur_ms}ms)'
  confidence: high
  suggestions:
  - 跳转性能良好，无需优化
```
### 无数据提示

- ID: `no_data_fallback`
- Type: `atomic`
- SQL: [`../sql/navigation_analysis/no_data_fallback.sql`](../sql/navigation_analysis/no_data_fallback.sql)

```yaml
id: no_data_fallback
type: atomic
display:
  level: key
  layer: overview
  title: 数据检查
  columns:
  - name: message
    label: 提示
    type: string
condition: lifecycle_check.data[0]?.status === 'unavailable'
```
## Output and evidence contract

```yaml
display:
  level: key
  format: summary
```
