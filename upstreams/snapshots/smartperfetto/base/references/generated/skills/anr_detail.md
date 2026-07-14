GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/anr_detail.skill.yaml
Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# ANR 详情分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: anr_detail
version: '2.0'
type: composite
category: app_lifecycle
tier: S
```

## Metadata

```yaml
display_name: ANR 详情分析
description: 深入分析单个 ANR 事件的原因
icon: find_in_page
tags:
- anr
- detail
- composite
```

## Prerequisites

```yaml
required_tables:
- slice
- process
modules:
- android.binder
- linux.cpu.frequency
- android.monitor_contention
```

## Inputs

```yaml
- name: anr_ts
  type: timestamp
  required: true
  description: ANR 发生时间戳(ns)
- name: timeout_ns
  type: timestamp
  required: true
  description: ANR 超时时间(ns)
- name: process_name
  type: string
  required: true
  description: 进程名
- name: pid
  type: integer
  required: true
  description: 进程 ID
- name: upid
  type: integer
  required: false
  default: 0
  description: Trace 内唯一进程 ID；优先用于逐 ANR 进程隔离
- name: anr_type
  type: string
  required: true
  description: ANR 类型
- name: error_id
  type: string
  required: false
  description: ANR error_id（用于逐事件证据隔离）
- name: intent
  type: string
  required: false
  description: ANR intent（如果 Perfetto 可提取）
- name: component
  type: string
  required: false
  description: ANR component（如果 Perfetto 可提取）
- name: anr_dur_ms
  type: number
  required: false
  description: ANR 持续时间(ms)
- name: perfetto_start
  type: timestamp
  required: false
  description: Perfetto 跳转开始时间
- name: perfetto_end
  type: timestamp
  required: false
  description: Perfetto 跳转结束时间
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
### ANR 基本信息

- ID: `anr_info`
- Type: `atomic`
- SQL: [`../sql/anr_detail/anr_info.sql`](../sql/anr_detail/anr_info.sql)

```yaml
id: anr_info
type: atomic
display:
  level: key
  layer: deep
  title: ANR 详情
  columns:
  - name: process_name
    label: 进程名
    type: string
  - name: pid
    label: PID
    type: number
  - name: upid
    label: UPID
    type: number
  - name: anr_type
    label: ANR 类型
    type: string
  - name: error_id
    label: Error ID
    type: string
  - name: anr_dur_ms
    label: ANR 持续时间
    type: duration
    format: duration_ms
  - name: timeout_ms
    label: 超时时间
    type: duration
    format: duration_ms
  - name: anr_ts
    label: ANR 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: perfetto_start
    label: 区间开始
    type: timestamp
    clickAction: navigate_timeline
  - name: perfetto_end
    label: 区间结束
    type: timestamp
    clickAction: navigate_timeline
  - name: type_display
    label: 类型说明
    type: string
save_as: anr_basic
```
### 主线程四象限分析

- ID: `main_thread_quadrant`
- Type: `atomic`
- SQL: [`../sql/anr_detail/main_thread_quadrant.sql`](../sql/anr_detail/main_thread_quadrant.sql)

```yaml
id: main_thread_quadrant
type: atomic
optional: true
display:
  level: key
  layer: deep
  title: 主线程状态分布
  columns:
  - name: q1_big_running_ms
    label: Q1大核运行(ms)
    type: number
  - name: q2_little_running_ms
    label: Q2小核运行(ms)
    type: number
  - name: q3_runnable_ms
    label: Q3可运行等待(ms)
    type: number
  - name: q4_sleeping_ms
    label: Q4睡眠阻塞(ms)
    type: number
  - name: total_ms
    label: 总时长(ms)
    type: number
  - name: running_pct
    label: Running占比(%)
    type: percentage
    format: percentage
  - name: runnable_pct
    label: Runnable占比(%)
    type: percentage
    format: percentage
  - name: sleeping_pct
    label: Sleeping占比(%)
    type: percentage
    format: percentage
  - name: status_verdict
    label: 状态判断
    type: string
save_as: quadrant
```
### 阻塞原因分析

- ID: `blocking_reasons`
- Type: `skill`

```yaml
id: blocking_reasons
type: skill
skill: main_thread_states_in_range
display:
  level: key
  layer: deep
  title: 阻塞原因 Top10
params:
  start_ts: ${anr_ts - timeout_ns}
  end_ts: ${anr_ts}
  upid: ${upid}
  pid: ${pid}
  package: ${process_name}
  top_k: 10
save_as: blocking
```
### RenderThread 分析

- ID: `render_thread_analysis`
- Type: `atomic`
- SQL: [`../sql/anr_detail/render_thread_analysis.sql`](../sql/anr_detail/render_thread_analysis.sql)

```yaml
id: render_thread_analysis
type: atomic
display:
  level: key
  layer: deep
  title: RenderThread 状态
  columns:
  - name: type
    label: 类型
    type: string
  - name: name
    label: 名称
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
  - name: pct
    label: 占比
    type: percentage
    format: percentage
save_as: render_thread
optional: true
```
### Binder 调用分析

- ID: `binder_calls`
- Type: `skill`

```yaml
id: binder_calls
type: skill
skill: binder_in_range
display:
  level: key
  layer: deep
  title: Binder 调用
params:
  start_ts: ${anr_ts - timeout_ns}
  end_ts: ${anr_ts}
  package: ${process_name}
save_as: binder_calls
optional: true
```
### 主线程同步 Binder

- ID: `main_thread_sync_binder`
- Type: `skill`

```yaml
id: main_thread_sync_binder
type: skill
skill: binder_blocking_in_range
display:
  level: detail
  layer: deep
  title: 主线程同步 Binder
params:
  start_ts: ${anr_ts - timeout_ns}
  end_ts: ${anr_ts}
  package: ${process_name}
save_as: main_sync_binder
optional: true
```
### 调度延迟分析

- ID: `sched_latency`
- Type: `skill`

```yaml
id: sched_latency
type: skill
skill: main_thread_sched_latency_in_range
display:
  level: detail
  layer: deep
  title: 主线程调度延迟
params:
  start_ts: ${anr_ts - timeout_ns}
  end_ts: ${anr_ts}
  package: ${process_name}
save_as: sched_delay
optional: true
```
### 锁竞争检测

- ID: `lock_contention`
- Type: `atomic`
- SQL: [`../sql/anr_detail/lock_contention.sql`](../sql/anr_detail/lock_contention.sql)

```yaml
id: lock_contention
type: atomic
display:
  level: key
  layer: deep
  title: 锁竞争
  columns:
  - name: blocking_method
    label: 持锁方法
    type: string
  - name: blocking_thread_name
    label: 持锁线程
    type: string
  - name: blocked_method
    label: 等锁方法
    type: string
  - name: blocked_thread_name
    label: 等锁线程
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: blocked_type
    label: 等锁类型
    type: string
  - name: wait_ms
    label: 等待时间
    type: duration
    format: duration_ms
  - name: waiter_count
    label: 等待者数
    type: number
    format: compact
  - name: severity
    label: 严重程度
    type: string
save_as: lock_contention
optional: true
```
### 应用冻结检测

- ID: `app_freeze_check`
- Type: `atomic`
- SQL: [`../sql/anr_detail/app_freeze_check.sql`](../sql/anr_detail/app_freeze_check.sql)

```yaml
id: app_freeze_check
type: atomic
optional: true
display:
  level: detail
  layer: deep
  title: 应用活动状态
  columns:
  - name: thread_type
    label: 线程类型
    type: string
  - name: running_ms
    label: 运行时间
    type: duration
    format: duration_ms
  - name: total_ms
    label: 总时间
    type: duration
    format: duration_ms
  - name: activity_pct
    label: 活动率
    type: percentage
    format: percentage
  - name: status
    label: 状态
    type: string
save_as: app_freeze_check
```
### 唤醒链分析

- ID: `wakeup_chain`
- Type: `atomic`
- SQL: [`../sql/anr_detail/wakeup_chain.sql`](../sql/anr_detail/wakeup_chain.sql)

```yaml
id: wakeup_chain
type: atomic
display:
  level: detail
  layer: deep
  title: 唤醒链
  columns:
  - name: waker_thread
    label: 唤醒线程
    type: string
  - name: waker_process
    label: 唤醒进程
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: wakeup_count
    label: 唤醒次数
    type: number
    format: compact
  - name: avg_sleep_ms
    label: 平均睡眠
    type: duration
    format: duration_ms
  - name: max_sleep_ms
    label: 最大睡眠
    type: duration
    format: duration_ms
  - name: total_sleep_ms
    label: 总睡眠
    type: duration
    format: duration_ms
save_as: wakeup
optional: true
```
### 主线程耗时操作

- ID: `main_thread_slices`
- Type: `skill`

```yaml
id: main_thread_slices
type: skill
skill: main_thread_slices_in_range
display:
  level: detail
  layer: deep
  title: 主线程操作
params:
  start_ts: ${anr_ts - timeout_ns}
  end_ts: ${anr_ts}
  upid: ${upid}
  pid: ${pid}
  package: ${process_name}
  min_dur_ns: 1000000
  top_k: 15
save_as: main_slices
optional: true
```
### 线程证据可用性

- ID: `thread_evidence_availability`
- Type: `atomic`
- SQL: [`../sql/anr_detail/thread_evidence_availability.sql`](../sql/anr_detail/thread_evidence_availability.sql)

```yaml
id: thread_evidence_availability
type: atomic
optional: true
display:
  level: hidden
save_as: thread_evidence_availability
```
### 直接阻塞点证据缺口

- ID: `direct_blocker_evidence_gap`
- Type: `atomic`
- SQL: [`../sql/anr_detail/direct_blocker_evidence_gap.sql`](../sql/anr_detail/direct_blocker_evidence_gap.sql)

```yaml
id: direct_blocker_evidence_gap
type: atomic
optional: true
display:
  level: key
  layer: deep
  title: 直接阻塞点候选
  columns:
  - name: direct_blocker_type
    label: 直接阻塞类型
    type: string
  - name: evidence_ms
    label: 证据时长
    type: duration
    format: duration_ms
    unit: ms
  - name: pct_of_timeout
    label: 超时占比
    type: percentage
    format: percentage
  - name: evidence_source
    label: 证据来源
    type: string
  - name: confidence
    label: 置信度
    type: string
  - name: root_cause_boundary
    label: 责任边界
    type: string
  - name: next_evidence_needed
    label: 下一步证据
    type: string
condition: thread_evidence_availability.data[0]?.has_thread_state !== 1
save_as: direct_blocker_gap
```
### 直接阻塞点候选

- ID: `direct_blocker_classification`
- Type: `atomic`
- SQL: [`../sql/anr_detail/direct_blocker_classification.sql`](../sql/anr_detail/direct_blocker_classification.sql)

```yaml
id: direct_blocker_classification
type: atomic
optional: true
display:
  level: key
  layer: deep
  title: 直接阻塞点候选
  columns:
  - name: direct_blocker_type
    label: 直接阻塞类型
    type: string
  - name: evidence_ms
    label: 证据时长
    type: duration
    format: duration_ms
    unit: ms
  - name: pct_of_timeout
    label: 超时占比
    type: percentage
    format: percentage
  - name: evidence_source
    label: 证据来源
    type: string
  - name: confidence
    label: 置信度
    type: string
  - name: root_cause_boundary
    label: 责任边界
    type: string
  - name: next_evidence_needed
    label: 下一步证据
    type: string
condition: thread_evidence_availability.data[0]?.has_thread_state === 1
save_as: direct_blocker_candidates
```
### Slice 直接阻塞点证据缺口

- ID: `direct_blocker_slice_evidence_gap`
- Type: `atomic`
- SQL: [`../sql/anr_detail/direct_blocker_slice_evidence_gap.sql`](../sql/anr_detail/direct_blocker_slice_evidence_gap.sql)

```yaml
id: direct_blocker_slice_evidence_gap
type: atomic
optional: true
display:
  level: detail
  layer: deep
  title: Slice 直接阻塞点候选
  columns:
  - name: direct_blocker_type
    label: 直接阻塞类型
    type: string
  - name: evidence_ms
    label: 证据时长
    type: duration
    format: duration_ms
    unit: ms
  - name: pct_of_timeout
    label: 超时占比
    type: percentage
    format: percentage
  - name: evidence_source
    label: 证据来源
    type: string
  - name: confidence
    label: 置信度
    type: string
  - name: root_cause_boundary
    label: 责任边界
    type: string
  - name: next_evidence_needed
    label: 下一步证据
    type: string
condition: thread_evidence_availability.data[0]?.has_thread_state === 1 && (thread_evidence_availability.data[0]?.has_thread_track
  !== 1 || thread_evidence_availability.data[0]?.has_slice !== 1)
save_as: direct_blocker_slice_gap
```
### Slice 直接阻塞点候选

- ID: `direct_blocker_slice_classification`
- Type: `atomic`
- SQL: [`../sql/anr_detail/direct_blocker_slice_classification.sql`](../sql/anr_detail/direct_blocker_slice_classification.sql)

```yaml
id: direct_blocker_slice_classification
type: atomic
optional: true
condition: thread_evidence_availability.data[0]?.has_thread_track === 1 && thread_evidence_availability.data[0]?.has_slice
  === 1
display:
  level: detail
  layer: deep
  title: Slice 直接阻塞点候选
  columns:
  - name: direct_blocker_type
    label: 直接阻塞类型
    type: string
  - name: evidence_ms
    label: 证据时长
    type: duration
    format: duration_ms
    unit: ms
  - name: pct_of_timeout
    label: 超时占比
    type: percentage
    format: percentage
  - name: evidence_source
    label: 证据来源
    type: string
  - name: confidence
    label: 置信度
    type: string
  - name: root_cause_boundary
    label: 责任边界
    type: string
  - name: next_evidence_needed
    label: 下一步证据
    type: string
save_as: direct_blocker_slice_candidates
```
### Logcat 表可用性

- ID: `logcat_availability`
- Type: `atomic`
- SQL: [`../sql/anr_detail/logcat_availability.sql`](../sql/anr_detail/logcat_availability.sql)

```yaml
id: logcat_availability
type: atomic
display:
  level: hidden
save_as: logcat_availability
optional: true
```
### 当前 ANR 日志证据缺口

- ID: `anr_logcat_evidence_gap`
- Type: `atomic`
- SQL: [`../sql/anr_detail/anr_logcat_evidence_gap.sql`](../sql/anr_detail/anr_logcat_evidence_gap.sql)

```yaml
id: anr_logcat_evidence_gap
type: atomic
optional: true
condition: logcat_availability.data[0]?.has_android_logs !== 1
display:
  level: detail
  layer: deep
  title: 当前 ANR 日志上下文
  columns:
  - name: error_id
    label: Error ID
    type: string
  - name: signal_type
    label: 信号类型
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
  - name: root_cause_eligible
    label: 可作根因证据
    type: boolean
  - name: msg_preview
    label: 消息
    type: string
save_as: logcat_context_gap
```
### 当前 ANR 日志上下文

- ID: `anr_logcat_context`
- Type: `atomic`
- SQL: [`../sql/anr_detail/anr_logcat_context.sql`](../sql/anr_detail/anr_logcat_context.sql)

```yaml
id: anr_logcat_context
type: atomic
optional: true
condition: logcat_availability.data[0]?.has_android_logs === 1
display:
  level: detail
  layer: deep
  title: 当前 ANR 日志上下文
  columns:
  - name: error_id
    label: Error ID
    type: string
  - name: relation_to_anr_ms
    label: 相对 ANR
    type: duration
    format: duration_ms
    unit: ms
  - name: phase
    label: 阶段
    type: string
  - name: signal_type
    label: 信号类型
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
  - name: root_cause_eligible
    label: 可作根因证据
    type: boolean
  - name: prio
    label: 级别
    type: string
  - name: tag
    label: Tag
    type: string
  - name: msg_preview
    label: 消息
    type: string
save_as: logcat_event_context
```
### ANR 事件诊断

- ID: `anr_event_diagnosis`
- Type: `diagnostic`

```yaml
id: anr_event_diagnosis
type: diagnostic
display:
  level: key
  layer: deep
  title: 诊断结果
inputs:
- anr_basic
- quadrant
- render_thread
- lock_contention
- app_freeze_check
- wakeup
- main_slices
- direct_blocker_gap
- direct_blocker_candidates
- direct_blocker_slice_gap
- direct_blocker_slice_candidates
- logcat_context_gap
- logcat_event_context
rules:
- condition: direct_blocker_gap.data?.find(r => r.direct_blocker_type === 'evidence_unavailable')
  severity: info
  diagnosis: 当前 trace 缺少 thread_state，直接阻塞点不可判定
  confidence: low
  suggestions:
  - 不要仅凭 trigger 或 logcat 作为最终根因
  - 需要包含 thread_state 的 trace 才能判断主线程直接阻塞形态
- condition: direct_blocker_slice_gap.data?.find(r => r.direct_blocker_type === 'slice_evidence_unavailable')
  severity: info
  diagnosis: 当前 trace 缺少 thread_track/slice，无法用 slice 判断 IO/GC/渲染候选
  confidence: low
  suggestions:
  - thread_state 直接阻塞点仍可使用
  - 不要把缺失 slice 解释为没有 IO/GC/渲染等待
- condition: logcat_context_gap.data?.find(r => r.signal_type === 'evidence_unavailable')
  severity: info
  diagnosis: 当前 trace 缺少 android_logs，无法用 Logcat/AnrManager 校验触发上下文
  confidence: low
  suggestions:
  - 保留该缺口，不要把缺失日志解释为没有系统/窗口/Binder 信号
  - 结合 Perfetto ANR 类型和线程状态继续分析
- condition: (quadrant.data[0]?.sleeping_pct || 0) > 80 && (direct_blocker_candidates.data?.find(r => ['binder_wait','lock_or_futex_wait','disk_or_page_fault_io','main_thread_sleep'].includes(r.direct_blocker_type)
    && r.confidence !== 'low') || direct_blocker_slice_candidates.data?.find(r => ['db_or_file_io_slice','render_or_fence_wait','gc_or_stw_wait'].includes(r.direct_blocker_type)
    && r.confidence !== 'low'))
  severity: warning
  diagnosis: 主线程 Sleeping/Blocked 占比 ${quadrant.data[0].sleeping_pct}%，存在逐事件 direct_blocker 候选；仍需对应的对端/owner/系统上下文闭环
  confidence: medium
  suggestions:
  - 以 direct_blocker_classification 为准，不使用包名级 blocking 结果单独定因
  - Binder wait 需要对端线程证据；锁等待需要 owner/monitor chain；IO/GC/Render 需要同窗口上下文
  - nativePoll/epoll 等待不满足该规则，不能单独作为根因
- condition: (quadrant.data[0]?.runnable_pct || 0) > 30 && direct_blocker_candidates.data?.find(r => r.direct_blocker_type
    === 'scheduler_pressure' && r.confidence !== 'low')
  severity: warning
  diagnosis: 主线程等待调度 ${quadrant.data[0].runnable_pct}%，direct_blocker 标记 scheduler_pressure；需要系统负载/拓扑/调度证据闭环
  confidence: medium
  suggestions:
  - 主线程想运行但拿不到 CPU
  - 检查同一 ANR 窗口的 CPU health、Top CPU process 和调度延迟
  - 不要只凭包名级 sched_latency 结果定因
- condition: quadrant.data[0]?.running_pct > 50 && quadrant.data[0]?.q1_big_running_ms < quadrant.data[0]?.q2_little_running_ms
    * 0.3 && quadrant.data[0]?.runnable_pct > 10 && direct_blocker_candidates.data?.find(r => r.direct_blocker_type === 'scheduler_pressure'
    && r.confidence !== 'low')
  severity: warning
  diagnosis: 主线程大核占比偏低且存在调度等待（Runnable ${quadrant.data[0].runnable_pct}%），可能有 CPU 供给不足
  confidence: medium
  suggestions:
  - 检查高优先级线程是否占用大核
  - 检查是否有高优先级任务抢占大核
  - 可能触发温控策略
- condition: direct_blocker_candidates.data?.find(r => r.direct_blocker_type === 'binder_wait')
  severity: warning
  diagnosis: 主线程存在 Binder 等待候选，但该证据只能说明客户端等待，不能直接定责对端
  confidence: medium
  suggestions:
  - 补查 Binder 对端进程、server_dur 或 system_server 线程状态
  - 将 Binder wait 作为 direct blocker candidate，而不是最终根因
- condition: direct_blocker_candidates.data?.find(r => r.direct_blocker_type === 'lock_or_futex_wait') && !(lock_contention.data?.find(r
    => r.blocked_type === 'MainThread'))
  severity: warning
  diagnosis: 主线程存在 futex/lock 等待候选，但缺少持锁线程/锁链证据
  confidence: medium
  suggestions:
  - 需要 android_monitor_contention、owner thread 或锁链证据确认
  - 不要把普通 futex_wait 直接写成死锁
- condition: direct_blocker_candidates.data?.find(r => r.direct_blocker_type === 'lock_or_futex_wait') && lock_contention.data?.find(r
    => r.blocked_type === 'MainThread' && r.severity === 'critical') && (quadrant.data[0]?.sleeping_pct || 0) > 50
  severity: critical
  diagnosis: 主线程严重锁竞争：等待 ${lock_contention.data.find(r => r.blocked_type === 'MainThread' && r.severity === 'critical')?.blocking_thread_name}
    ${lock_contention.data.find(r => r.blocked_type === 'MainThread' && r.severity === 'critical')?.wait_ms}ms
  confidence: high
  suggestions:
  - 存在当前 ANR 进程主线程严重锁竞争
  - 持锁线程：${lock_contention.data.find(r => r.blocked_type === 'MainThread' && r.severity === 'critical')?.blocking_thread_name}
  - 阻塞方法：${lock_contention.data.find(r => r.blocked_type === 'MainThread' && r.severity === 'critical')?.blocking_method}
- condition: direct_blocker_candidates.data?.find(r => r.direct_blocker_type === 'lock_or_futex_wait') && lock_contention.data?.find(r
    => r.blocked_type === 'MainThread') && (quadrant.data[0]?.sleeping_pct || 0) > 30
  severity: warning
  diagnosis: 主线程被锁阻塞
  confidence: high
  suggestions:
  - 主线程在等待获取锁
  - 避免主线程持有长时间锁
  - 考虑使用异步操作或减少锁粒度
- condition: direct_blocker_candidates.data?.find(r => r.direct_blocker_type === 'native_poll_idle_or_ambiguous') && !direct_blocker_candidates.data?.find(r
    => ['binder_wait','lock_or_futex_wait','disk_or_page_fault_io'].includes(r.direct_blocker_type)) && !direct_blocker_slice_candidates.data?.find(r
    => ['db_or_file_io_slice','render_or_fence_wait'].includes(r.direct_blocker_type))
  severity: info
  diagnosis: 主线程主要表现为 native poll/epoll 等待；这是 idle-or-ambiguous 证据，不能单独作为 ANR 根因
  confidence: low
  suggestions:
  - 结合 EventLog/Logcat 的 input/no-focus/window 时间线判断真实触发链
  - 检查系统负载、焦点窗口、对端 Binder 或渲染链路是否是上游原因
- condition: render_thread.data?.find(r => r.name?.includes('nSyncDraw') && r.dur_ms > 50) && (quadrant.data[0]?.sleeping_pct
    || 0) > 30
  severity: warning
  diagnosis: RenderThread nSyncDraw 阻塞 ${render_thread.data.find(r => r.name?.includes('nSyncDraw'))?.dur_ms}ms
  confidence: high
  suggestions:
  - 渲染同步点阻塞
  - 可能与主线程有同步等待
  - 检查是否有复杂绘制操作
- condition: render_thread.data?.find(r => r.name?.includes('dequeueBuffer') && r.dur_ms > 50) && (quadrant.data[0]?.sleeping_pct
    || 0) > 30
  severity: warning
  diagnosis: RenderThread dequeueBuffer 阻塞 ${render_thread.data.find(r => r.name?.includes('dequeueBuffer'))?.dur_ms}ms
  confidence: medium
  suggestions:
  - 等待 SurfaceFlinger 分配 Buffer
  - 可能是显示系统繁忙
  - 检查是否有大量图形渲染
- condition: app_freeze_check.data?.find(r => r.thread_type === 'MainThread')?.status === 'frozen' && app_freeze_check.data?.find(r
    => r.thread_type === 'RenderThread')?.status === 'frozen' && app_freeze_check.data?.find(r => r.thread_type === 'Binder')?.status
    === 'frozen' && (quadrant.data[0]?.sleeping_pct || 0) > 80
  severity: critical
  diagnosis: 应用完全冻结，主线程活动率仅 ${app_freeze_check.data.find(r => r.thread_type === 'MainThread')?.activity_pct}%
  confidence: high
  suggestions:
  - MainThread、RenderThread、Binder 均几乎没有活动
  - 可能是死锁或严重阻塞
  - 检查 direct_blocker、锁 owner、Binder 对端或系统上下文
- condition: app_freeze_check.data?.find(r => r.thread_type === 'MainThread')?.status === 'frozen' && (quadrant.data[0]?.sleeping_pct
    || 0) > 80 && !(app_freeze_check.data?.find(r => r.thread_type === 'RenderThread')?.status === 'frozen' && app_freeze_check.data?.find(r
    => r.thread_type === 'Binder')?.status === 'frozen')
  severity: warning
  diagnosis: 主线程冻结/低活动，不能直接等同应用完全冻结
  confidence: medium
  suggestions:
  - 检查 RenderThread、Binder 线程是否仍活跃
  - 按 direct_blocker、锁 owner、Binder 对端或系统上下文继续定因
  - 只有 MainThread、RenderThread、Binder 均冻结时才报告应用完全冻结
```
## Output and evidence contract

```yaml
display:
  level: key
  format: summary
```
