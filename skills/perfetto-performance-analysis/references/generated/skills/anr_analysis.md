GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/anr_analysis.skill.yaml
Source SHA-256: 9a20a24042252892aabc8ff420a5f4777953bd6c041b00285dc3402f3cf6182e
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# ANR 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: anr_analysis
version: '1.0'
type: composite
category: app_lifecycle
tier: S
```

## Metadata

```yaml
display_name: ANR 分析
description: 检测和分析应用程序无响应 (ANR) 事件
icon: error
tags:
- anr
- freeze
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - ANR
  - 无响应
  - 卡死
  - 超时
  - 广播超时
  - 输入超时
  - 服务超时
  - 应用无响应
  en:
  - ANR
  - not responding
  - timeout
  - broadcast timeout
  - input timeout
  - application hang
patterns:
- .*ANR.*
- .*无响应.*
- .*timeout.*
- .*卡死.*
```

## Prerequisites

```yaml
modules:
- android.anrs
- android.binder
- android.memory.lmk
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
  description: 目标进程名，留空分析所有 ANR
- name: package
  type: string
  required: false
  description: 应用包名（process_name 的别名）
- name: anr_type
  type: string
  required: false
  description: ANR 类型过滤
- name: multi_anr_threshold
  type: number
  required: false
  default: 3
  description: 多 ANR 系统级问题阈值
- name: multi_anr_span_seconds
  type: number
  required: false
  default: 10
  description: 多 ANR 时间窗口（秒）
- name: io_wait_threshold_ms
  type: number
  required: false
  default: 500
  description: 兼容旧调用的 D-state 不可中断等待告警阈值（ms）；不能单独作为 IO 根因
- name: uninterruptible_wait_threshold_ms
  type: number
  required: false
  default: 500
  description: D-state 不可中断等待告警阈值（ms）；需要 blocked_function/slice/系统 IO 证据才能升级为 IO
- name: enable_lock_probe
  type: boolean
  required: false
  default: true
  description: 是否启用锁等待探针（futex/mutex）
- name: lock_contention_futex_p95_critical_ms
  type: number
  required: false
  default: 20
  description: Futex P95 严重锁竞争阈值（ms）
- name: lock_contention_mutex_p95_warning_ms
  type: number
  required: false
  default: 10
  description: Mutex P95 锁等待告警阈值（ms）
- name: enable_detail_analysis
  type: boolean
  required: false
  default: true
  description: 是否执行逐 ANR 深度分析；测试或快速预览可设为 false
```

## Ordered execution

### 初始化 CPU 拓扑

- ID: `init_cpu_topology`
- Type: `skill`

```yaml
id: init_cpu_topology
type: skill
skill: cpu_topology_view
display:
  level: hidden
optional: true
```
### 提取 ANR 上下文

- ID: `get_anr_context`
- Type: `skill`

```yaml
id: get_anr_context
type: skill
skill: anr_context_in_range
params:
  process_name: ${process_name}
  package: ${package}
  anr_type: ${anr_type}
save_as: anr_ctx
display:
  level: hidden
optional: true
```
### ANR 检测

- ID: `anr_detection`
- Type: `atomic`
- SQL: [`../sql/anr_analysis/anr_detection.sql`](../sql/anr_analysis/anr_detection.sql)

```yaml
id: anr_detection
type: atomic
display:
  level: key
  layer: overview
  title: ANR 检测
  columns:
  - name: total_anr_count
    label: ANR 总数
    type: number
  - name: affected_process_count
    label: 受影响进程数
    type: number
  - name: first_anr_ts
    label: 首次 ANR
    type: timestamp
    clickAction: navigate_timeline
  - name: last_anr_ts
    label: 末次 ANR
    type: timestamp
    clickAction: navigate_timeline
  - name: anr_span_seconds
    label: 时间跨度(秒)
    type: number
    format: compact
synthesize:
  role: overview
  fields:
  - key: total_anr_count
    label: ANR 总数
  - key: affected_process_count
    label: 受影响进程数
  - key: anr_span_seconds
    label: ANR 时间跨度
    format: '{{value}} 秒'
  insights:
  - condition: total_anr_count === 0
    template: 未检测到 ANR 事件
  - condition: total_anr_count > 0 && total_anr_count <= 3
    template: 检测到 {{total_anr_count}} 个 ANR 事件，影响 {{affected_process_count}} 个进程
  - condition: total_anr_count > 3
    template: ⚠️ 检测到 {{total_anr_count}} 个 ANR，可能是系统级问题
save_as: detection
optional: true
on_empty: 未检测到 ANR 事件。请确认 Trace 包含 ANR 数据。
```
### ANR 触发类型分类

- ID: `trigger_classification`
- Type: `atomic`
- SQL: [`../sql/anr_analysis/trigger_classification.sql`](../sql/anr_analysis/trigger_classification.sql)

```yaml
id: trigger_classification
type: atomic
display:
  level: key
  layer: overview
  title: ANR 触发类型
  columns:
  - name: source_anr_type
    label: Perfetto 类型
    type: string
  - name: trigger_type
    label: 触发类型
    type: string
  - name: event_count
    label: 事件数
    type: number
  - name: type_confidence
    label: 类型置信度
    type: string
  - name: root_cause_pattern_hints
    label: 候选根因提示
    type: string
  - name: not_final
    label: 非最终根因
    type: boolean
  - name: analysis_focus
    label: 分析重点
    type: string
synthesize:
  role: overview
  fields:
  - key: trigger_type
    label: 触发类型
  - key: event_count
    label: 事件数
  - key: root_cause_pattern_hints
    label: 候选提示
  insights:
  - template: ANR 触发类型 {{trigger_type}}（{{event_count}} 次）；候选根因提示只作为排查入口，不是最终结论
save_as: trigger_classification
condition: detection.data[0]?.total_anr_count > 0
```
### 系统 CPU 健康状况

- ID: `system_cpu_health`
- Type: `atomic`
- SQL: [`../sql/anr_analysis/system_cpu_health.sql`](../sql/anr_analysis/system_cpu_health.sql)

```yaml
id: system_cpu_health
type: atomic
display:
  level: key
  layer: overview
  title: 首个 ANR 窗口系统 CPU 状况
  columns:
  - name: core_type
    label: 核心类型
    type: string
  - name: core_count
    label: 核心数
    type: number
  - name: total_active_ms
    label: 活跃时间
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_util_pct
    label: 平均利用率
    type: percentage
    format: percentage
  - name: status
    label: 状态
    type: string
synthesize:
  role: overview
  fields:
  - key: core_type
    label: 核心类型
  - key: avg_util_pct
    label: 平均利用率
    format: '{{value}}%'
  - key: status
    label: 状态
  insights:
  - condition: status === 'overloaded'
    template: ⚠️ {{core_type}} 核心过载 ({{avg_util_pct}}%)，系统繁忙
  - condition: status === 'busy'
    template: '{{core_type}} 核心较忙 ({{avg_util_pct}}%)'
  - condition: status === 'normal'
    template: '{{core_type}} 核心负载正常 ({{avg_util_pct}}%)'
save_as: cpu_health
condition: detection.data[0]?.total_anr_count > 0
optional: true
```
### 内存压力检测

- ID: `memory_pressure`
- Type: `atomic`
- SQL: [`../sql/anr_analysis/memory_pressure.sql`](../sql/anr_analysis/memory_pressure.sql)

```yaml
id: memory_pressure
type: atomic
display:
  level: detail
  layer: list
  title: 首个 ANR 窗口内存压力
  columns:
  - name: oom_score_adj
    label: OOM Score
    type: number
  - name: kill_count
    label: Kill 次数
    type: number
    format: compact
  - name: killed_processes
    label: 被杀进程
    type: string
save_as: memory_pressure
condition: detection.data[0]?.total_anr_count > 0
optional: true
```
### 不可中断等待基线

- ID: `io_load`
- Type: `atomic`
- SQL: [`../sql/anr_analysis/io_load.sql`](../sql/anr_analysis/io_load.sql)

```yaml
id: io_load
type: atomic
display:
  level: detail
  layer: list
  title: 首个 ANR 窗口 D-state 不可中断等待
  columns:
  - name: process_name
    label: 进程名
    type: string
  - name: uninterruptible_wait_ms
    label: 不可中断等待
    type: duration
    format: duration_ms
    unit: ms
  - name: uninterruptible_wait_count
    label: 等待次数
    type: number
    format: compact
save_as: io_load
condition: detection.data[0]?.total_anr_count > 0
optional: true
```
### ANR 锁等待探针

- ID: `futex_wait_probe`
- Type: `skill`

```yaml
id: futex_wait_probe
type: skill
skill: futex_wait_distribution
params:
  package: ${package || process_name || anr_ctx.data?.[0]?.process_name || ''}
  start_ts: '${anr_ctx.data?.[0]?.anr_ts != null && anr_ctx.data?.[0]?.timeout_ns != null ? (Number(anr_ctx.data[0].anr_ts)
    - Number(anr_ctx.data[0].timeout_ns)) : null}'
  end_ts: ${anr_ctx.data?.[0]?.anr_ts ?? null}
display:
  level: detail
  layer: list
  title: 首个 ANR 窗口锁等待分布（专家探针）
  columns:
  - name: wait_type
    label: 等待类型
    type: string
  - name: events
    label: 事件数
    type: number
  - name: avg_wait_ms
    label: 平均等待
    type: duration
    format: duration_ms
    unit: ms
  - name: p95_wait_ms
    label: P95 等待
    type: duration
    format: duration_ms
    unit: ms
  - name: max_wait_ms
    label: 最大等待
    type: duration
    format: duration_ms
    unit: ms
save_as: lock_waits
condition: detection.data[0]?.total_anr_count > 0 && enable_lock_probe !== false
optional: true
```
### 系统冻结检测

- ID: `system_freeze_check`
- Type: `atomic`
- SQL: [`../sql/anr_analysis/system_freeze_check.sql`](../sql/anr_analysis/system_freeze_check.sql)

```yaml
id: system_freeze_check
type: atomic
display:
  level: key
  layer: overview
  title: 首个 ANR 窗口系统冻结检测
  columns:
  - name: total_apps
    label: 检测应用数
    type: number
  - name: frozen_apps
    label: 冻结应用数
    type: number
  - name: frozen_pct
    label: 冻结占比
    type: percentage
    format: percentage
  - name: freeze_verdict
    label: 判定
    type: string
  - name: system_server_running_pct
    label: system_server 运行占比
    type: percentage
    format: percentage
  - name: system_server_frozen
    label: system_server 冻结
    type: boolean
save_as: freeze_check
condition: detection.data[0]?.total_anr_count > 0
optional: true
```
### ANR 概览统计

- ID: `anr_overview`
- Type: `atomic`
- SQL: [`../sql/anr_analysis/anr_overview.sql`](../sql/anr_analysis/anr_overview.sql)

```yaml
id: anr_overview
type: atomic
display:
  level: key
  layer: overview
  title: ANR 概览
  columns:
  - name: anr_type
    label: ANR 类型
    type: string
  - name: trigger_type
    label: 触发类型
    type: string
  - name: anr_count
    label: 数量
    type: number
    format: compact
  - name: affected_processes
    label: 受影响进程
    type: string
  - name: avg_anr_dur_ms
    label: 平均超时时长
    type: duration
    format: duration_ms
    unit: ms
  - name: default_timeout_ms
    label: 默认超时
    type: duration
    format: duration_ms
    unit: ms
  - name: type_display
    label: 类型说明
    type: string
  - name: quick_hint
    label: 快速提示
    type: string
  - name: root_cause_pattern_hints
    label: 候选根因提示
    type: string
  - name: not_final
    label: 非最终根因
    type: boolean
synthesize:
  role: overview
  fields:
  - key: anr_type
    label: ANR 类型
  - key: trigger_type
    label: 触发类型
  - key: anr_count
    label: 数量
  - key: type_display
    label: 类型说明
  - key: avg_anr_dur_ms
    label: 平均超时时长
    format: '{{value}} ms'
  insights:
  - condition: anr_type === 'INPUT_DISPATCHING_TIMEOUT'
    template: 输入超时 {{anr_count}} 次：主线程 5 秒未响应
  - condition: anr_type === 'BROADCAST_OF_INTENT'
    template: 广播超时 {{anr_count}} 次：BroadcastReceiver 处理超时
  - condition: anr_type === 'EXECUTING_SERVICE'
    template: 服务超时 {{anr_count}} 次：Service 生命周期方法超时
save_as: overview
condition: detection.data[0]?.total_anr_count > 0
```
### 获取 ANR 事件列表

- ID: `get_anr_events`
- Type: `atomic`
- SQL: [`../sql/anr_analysis/get_anr_events.sql`](../sql/anr_analysis/get_anr_events.sql)

```yaml
id: get_anr_events
type: atomic
display:
  level: key
  layer: list
  title: ANR 事件列表
  columns:
  - name: error_id
    label: Error ID
    type: number
  - name: process_name
    label: 进程名
    type: string
  - name: pid
    label: PID
    type: number
  - name: anr_type
    label: ANR 类型
    type: string
  - name: trigger_type
    label: 触发类型
    type: string
  - name: anr_dur_ms
    label: 超时时长
    type: duration
    format: duration_ms
    unit: ms
  - name: anr_ts
    label: ANR 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: perfetto_start
    label: 区间开始
    type: timestamp
    clickAction: navigate_range
    durationColumn: timeout_ns
  - name: type_display
    label: 类型
    type: string
  - name: timeout_source
    label: 窗口来源
    type: string
  - name: analysis_focus
    label: 分析重点
    type: string
  - name: subject_preview
    label: 摘要
    type: string
  - name: root_cause_pattern_hints
    label: 候选提示
    type: string
synthesize:
  role: list
  groupBy:
    field: anr_type
    label: ANR 类型
    aggregations:
    - type: count
      label: 数量
    - type: avg
      field: anr_dur_ms
      label: 平均耗时
  fields:
  - key: process_name
    label: 进程名
  - key: type_display
    label: 类型
  - key: trigger_type
    label: 触发类型
  - key: anr_dur_ms
    label: 超时时长
    format: '{{value}} ms'
save_as: anr_events
condition: detection.data[0]?.total_anr_count > 0
```
### Top CPU 进程

- ID: `top_cpu_processes`
- Type: `atomic`
- SQL: [`../sql/anr_analysis/top_cpu_processes.sql`](../sql/anr_analysis/top_cpu_processes.sql)

```yaml
id: top_cpu_processes
type: atomic
display:
  level: detail
  layer: list
  title: 首个 ANR 窗口 Top CPU 进程
  columns:
  - name: process_name
    label: 进程名
    type: string
  - name: cpu_ms
    label: CPU 时间
    type: duration
    format: duration_ms
    unit: ms
  - name: cpu_pct
    label: CPU 占比
    type: percentage
    format: percentage
save_as: top_processes
condition: detection.data[0]?.total_anr_count > 0
optional: true
```
### ANR 事件详细分析

- ID: `analyze_anr_events`
- Type: `iterator`

```yaml
id: analyze_anr_events
type: iterator
display:
  level: key
  layer: deep
  title: ANR 深度分析
synthesize:
  role: clusters
  clusterBy:
    field: anr_type
    label: ANR 类型
  fields:
  - key: process_name
    label: 进程名
  - key: anr_type
    label: 类型
  - key: main_thread_state
    label: 主线程状态
  - key: blocking_reason
    label: 阻塞原因
  insights:
  - template: ANR 事件详细分析，按类型分组
source: anr_events
item_skill: anr_detail
item_params:
  anr_ts: anr_ts
  timeout_ns: timeout_ns
  process_name: process_name
  pid: pid
  upid: upid
  anr_type: anr_type
  error_id: error_id
  intent: intent
  component: component
  anr_dur_ms: anr_dur_ms
  perfetto_start: perfetto_start
  perfetto_end: perfetto_end
condition: detection.data[0]?.total_anr_count > 0 && enable_detail_analysis !== false
```
### ANR 诊断

- ID: `anr_diagnosis`
- Type: `diagnostic`

```yaml
id: anr_diagnosis
type: diagnostic
display:
  level: key
  layer: overview
  title: 问题诊断
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
  - condition: severity === 'critical'
    template: 🔴 严重问题：{{diagnosis}}
  - condition: severity === 'warning'
    template: 🟡 警告：{{diagnosis}}
  - template: ANR 诊断：{{diagnosis}}
inputs:
- detection
- trigger_classification
- cpu_health
- memory_pressure
- io_load
- lock_waits
- freeze_check
- overview
- anr_events
- top_processes
rules:
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && freeze_check.data[0]?.freeze_verdict === 'system_server_freeze'
  severity: critical
  diagnosis: system_server 运行占比仅 ${freeze_check.data[0].system_server_running_pct}%（疑似系统服务冻结）
  confidence: high
  suggestions:
  - 这是系统级问题，优先排查 system_server 调度阻塞
  - 检查 Binder 死锁、IO 堵塞和内核锁等待
  - 结合内核调度与系统服务线程栈定位阻塞点
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && freeze_check.data[0]?.freeze_verdict === 'system_freeze'
  severity: critical
  diagnosis: 系统级冻结：${freeze_check.data[0].frozen_apps}/${freeze_check.data[0].total_apps} 个应用主线程几乎无运行
  confidence: high
  suggestions:
  - 这是系统级问题，非单个应用问题
  - 检查系统服务是否正常
  - 检查是否有内核级阻塞（内存/IO/锁）
- condition: (detection.data[0]?.total_anr_count || 0) > 1 && freeze_check.data[0]?.freeze_verdict === 'system_server_freeze'
  severity: warning
  diagnosis: 首个 ANR 窗口 baseline 显示 system_server 运行占比仅 ${freeze_check.data[0].system_server_running_pct}%，需逐 ANR 复核后才能升级为系统根因
  confidence: medium
  suggestions:
  - 该 freeze_check 只覆盖首个 ANR 窗口
  - 多 ANR 必须逐事件检查 direct_blocker、日志和系统线程证据
  - 不要把首个窗口 system_server_freeze 直接推广到所有 ANR
- condition: (detection.data[0]?.total_anr_count || 0) > 1 && freeze_check.data[0]?.freeze_verdict === 'system_freeze'
  severity: warning
  diagnosis: 首个 ANR 窗口 baseline 显示 ${freeze_check.data[0].frozen_apps}/${freeze_check.data[0].total_apps} 个应用主线程低活动，需逐 ANR
    复核后才能升级为系统根因
  confidence: medium
  suggestions:
  - 该 freeze_check 只覆盖首个 ANR 窗口
  - 多 ANR 必须逐事件检查 direct_blocker、日志和系统上下文
  - 若后续 ANR 窗口没有系统冻结证据，只能作为候选背景
- condition: detection.data[0]?.total_anr_count > (multi_anr_threshold || 3) && detection.data[0]?.anr_span_seconds < (multi_anr_span_seconds
    || 10)
  severity: critical
  diagnosis: 短时间内发生 ${detection.data[0].total_anr_count} 个 ANR，间隔仅 ${detection.data[0].anr_span_seconds}s
  confidence: high
  suggestions:
  - 多个 ANR 集中发生通常指向系统级问题
  - 检查系统是否过载或有资源争抢
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && memory_pressure.data?.length > 0
  severity: critical
  diagnosis: ANR 期间发生 LMK 杀进程，系统内存压力大
  confidence: high
  suggestions:
  - 内存不足导致系统繁忙，影响应用响应
  - 检查内存占用大户
  - 考虑减少内存使用
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && cpu_health.data?.find(r => r.status === 'overloaded')
  severity: critical
  diagnosis: CPU ${cpu_health.data.find(r => r.status === 'overloaded').core_type} 核过载 (${cpu_health.data.find(r => r.status
    === 'overloaded').avg_util_pct}%)
  confidence: high
  suggestions:
  - CPU 资源严重不足
  - 检查后台进程 CPU 占用
  - top_processes 显示的进程可能是罪魁祸首
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && io_load.data[0]?.uninterruptible_wait_ms > (uninterruptible_wait_threshold_ms
    || io_wait_threshold_ms || 500)
  severity: warning
  diagnosis: 进程 ${io_load.data[0].process_name} D-state 不可中断等待 ${io_load.data[0].uninterruptible_wait_ms}ms
  confidence: low
  suggestions:
  - D-state 只能说明不可中断等待，不能单独证明磁盘 IO
  - 只有 blocked_function、slice 或 block IO 证据命中 io_schedule/fsync/blk/ext4/f2fs/filemap_fault 等路径时，才升级为 IO 根因
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && (lock_waits?.data?.find(r => r.wait_type === 'futex')?.p95_wait_ms
    || 0) > (lock_contention_futex_p95_critical_ms || 20)
  severity: warning
  diagnosis: ANR 窗口 Futex P95 等待 ${lock_waits.data.find(r => r.wait_type === 'futex').p95_wait_ms}ms，存在锁等待候选信号
  confidence: medium
  suggestions:
  - 这是包名级专家探针，不能作为最终根因
  - 必须结合逐 ANR direct_blocker_classification 和当前进程 MainThread lock_contention 再判断
  - 若确认主线程锁等待，再排查持锁线程、锁顺序和锁内 Binder/IO/数据库操作
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && (lock_waits?.data?.find(r => r.wait_type === 'mutex')?.p95_wait_ms
    || 0) > (lock_contention_mutex_p95_warning_ms || 10)
  severity: warning
  diagnosis: ANR 窗口 Mutex P95 等待 ${lock_waits.data.find(r => r.wait_type === 'mutex').p95_wait_ms}ms，锁等待偏高
  confidence: medium
  suggestions:
  - 按热点函数重构锁粒度，降低串行化路径
  - 评估是否可用无锁队列或分段锁替换
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && trigger_classification.data?.find(r => r.trigger_type ===
    'no_focus_window')
  severity: warning
  diagnosis: 触发类型分流：无焦点窗口输入超时，需要窗口焦点链证据闭环
  confidence: medium
  suggestions:
  - 按 Activity resume → relayout → draw/focus 顺序检查窗口建立链路
  - 若主线程只呈现 nativePoll/epoll，不要单独归因为 Looper 空闲
  - 结合 WindowManager/InputDispatcher/AnrManager 日志确认焦点丢失阶段
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && trigger_classification.data?.find(r => r.trigger_type ===
    'job_scheduler_timeout')
  severity: warning
  diagnosis: 触发类型分流：JobScheduler 相关 ANR，需要 JobService 回调或绑定链路证据
  confidence: medium
  suggestions:
  - 检查 onStartJob/onStopJob/onBind 是否在主线程执行耗时操作
  - 检查 JobScheduler 与应用进程之间的 Binder 调用是否有对端等待
  - 不要只按普通 Service 超时处理，需保留 JobService 回调语义
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && trigger_classification.data?.find(r => r.trigger_type ===
    'system_watchdog_swt')
  severity: warning
  diagnosis: 触发类型分流：system_server Watchdog/SWT，需要系统服务线程证据闭环
  confidence: medium
  suggestions:
  - 优先排查 system_server Handler、锁和 Binder 线程池
  - 除非有明确同步 Binder 反向证据，否则不要归因为目标 App
  - 结合 system_server 线程状态、monitor contention 与系统日志闭环
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && top_processes.data?.find(p => p.process_name === anr_events.data?.[0]?.process_name
    && p.cpu_pct > 85)
  severity: warning
  diagnosis: 目标进程在 ANR 窗口 CPU 占比 ${top_processes.data.find(p => p.process_name === anr_events.data?.[0]?.process_name && p.cpu_pct
    > 85).cpu_pct}%
  confidence: medium
  suggestions:
  - 这是 high_load_anr 候选证据，需要和主线程热点、调度延迟或 GC/内存压力交叉验证
  - 优先检查主线程 Running 热点和后台线程是否抢占关键核心
  - 不要仅凭 CPU 占比高给出最终根因
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && trigger_classification.data?.find(r => r.trigger_type ===
    'input_dispatching_timeout')
  severity: warning
  diagnosis: 触发类型分流：输入事件超时，需要 direct_blocker/线程状态/日志证据闭环
  confidence: medium
  suggestions:
  - 主线程 5 秒未处理输入是触发机制，不是最终根因
  - 检查逐 ANR direct_blocker_classification 中的 Binder/锁/IO/调度候选
  - 只有线程状态、对端或日志证据闭环后才能升级为根因
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && trigger_classification.data?.find(r => r.trigger_type ===
    'broadcast_timeout')
  severity: warning
  diagnosis: 触发类型分流：广播处理超时，需要 onReceive/goAsync/finish 链路证据
  confidence: medium
  suggestions:
  - 广播超时只说明超时入口，不能直接等同业务代码根因
  - 区分前台/后台广播窗口，并检查工作线程或 Binder 对端
  - 需要当前 ANR 的线程状态、日志或组件证据闭环
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && trigger_classification.data?.find(r => r.trigger_type ===
    'service_timeout')
  severity: warning
  diagnosis: 触发类型分流：服务生命周期超时，需要 Service/FGS 链路证据
  confidence: medium
  suggestions:
  - Service/FGS 超时是触发类型，不能单独作为最终根因
  - 检查 onCreate/onStartCommand/onBind/startForeground 调用链
  - 结合 direct_blocker 与日志证据确认是主线程、对端还是系统资源问题
- condition: (detection.data[0]?.total_anr_count || 0) === 1 && trigger_classification.data?.find(r => r.trigger_type ===
    'content_provider_timeout')
  severity: warning
  diagnosis: 触发类型分流：ContentProvider 超时，需要 provider 发布/查询链路证据
  confidence: medium
  suggestions:
  - ContentProvider not responding 只说明触发入口
  - 检查 provider 主线程、Binder 线程、数据库/文件 IO 和调用方等待
  - 没有逐事件阻塞证据时不要写成最终根因
```
## Output and evidence contract

```yaml
format: structured
```
