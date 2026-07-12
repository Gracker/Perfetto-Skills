GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/cpu_analysis.skill.yaml
Source SHA-256: c2723137b1cdfaa2c0f8b23cc62a9133aa534e56dc981c472ddc8d28ca6dff14
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d
# CPU 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_analysis
version: '1.0'
type: composite
category: hardware
tier: S
```

## Metadata

```yaml
display_name: CPU 分析
description: 全方位的 CPU 性能分析
icon: memory
tags:
- cpu
- usage
- frequency
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - CPU
  - CPU利用率
  - CPU占用
  - 线程调度
  - 大核
  - 小核
  - 调度延迟
  en:
  - cpu
  - cpu usage
  - thread scheduling
  - frequency
  - core
  - big core
  - little
patterns:
- .*CPU.*
- .*cpu.*
- .*核心.*
- .*调度.*
```

## Prerequisites

```yaml
modules:
- linux.cpu.frequency
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
  description: 分析起始时间（可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间（可选）
- name: big_core_threshold_pct
  type: number
  required: false
  default: 30
  description: 大核使用率告警阈值（%）
- name: running_threshold_pct
  type: number
  required: false
  default: 50
  description: 主线程 Running 告警阈值（%）
- name: sched_delay_critical_ms
  type: number
  required: false
  default: 16
  description: 调度延迟严重阈值（ms）
- name: blocked_function_threshold_ms
  type: number
  required: false
  default: 50
  description: 阻塞函数告警阈值（ms）
- name: enable_expert_probes
  type: boolean
  required: false
  default: true
  description: 是否启用专家探针（迁核/Cache miss）
- name: affinity_probe_migration_ratio_threshold_pct
  type: number
  required: false
  default: 25
  description: 线程亲和性探针判定阈值（%）
- name: affinity_violation_warning_threshold_pct
  type: number
  required: false
  default: 35
  description: 线程迁核告警阈值（%）
- name: cache_miss_high_avg_delta_threshold
  type: number
  required: false
  default: 500000
  description: Cache miss 高影响阈值（平均增量）
- name: cache_miss_medium_avg_delta_threshold
  type: number
  required: false
  default: 100000
  description: Cache miss 中影响阈值（平均增量）
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
### 获取目标进程

- ID: `get_process`
- Type: `atomic`
- SQL: [`../sql/cpu_analysis/get_process.sql`](../sql/cpu_analysis/get_process.sql)

```yaml
id: get_process
type: atomic
display:
  level: summary
  layer: overview
  title: 目标进程
  columns:
  - name: upid
    label: UPID
    type: number
    format: compact
  - name: pid
    label: PID
    type: number
    format: compact
  - name: process_name
    label: 进程名
    type: string
save_as: target_process
on_empty: 未找到目标进程
```
### 核心类型统计

- ID: `core_type_stats`
- Type: `atomic`
- SQL: [`../sql/cpu_analysis/core_type_stats.sql`](../sql/cpu_analysis/core_type_stats.sql)

```yaml
id: core_type_stats
type: atomic
synthesize:
  role: overview
  fields:
  - key: core_type
    label: 核心类型
  - key: total_time_ms
    label: 运行时间
    format: '{{value}} ms ({{percent}}%)'
  - key: core_count
    label: 核心数
  insights:
  - condition: core_type.includes('big') && percent < (big_core_threshold_pct || 30)
    template: 大核使用率仅 {{percent}}%，建议优化调度策略
display:
  level: key
  layer: overview
  title: 大小核分布（基于 capacity）
  columns:
  - name: core_type
    label: 核心类型
    type: string
  - name: capacity
    label: Capacity
    type: number
    format: compact
  - name: total_time_ms
    label: 运行时间
    type: duration
    format: duration_ms
    unit: ms
  - name: percent
    label: 占比
    type: percentage
    format: percentage
  - name: slice_count
    label: 调度次数
    type: number
    format: compact
  - name: core_count
    label: 核心数
    type: number
save_as: core_stats
condition: target_process.data.length > 0
```
### 线程 CPU 使用

- ID: `thread_cpu_usage`
- Type: `atomic`
- SQL: [`../sql/cpu_analysis/thread_cpu_usage.sql`](../sql/cpu_analysis/thread_cpu_usage.sql)

```yaml
id: thread_cpu_usage
type: atomic
synthesize:
  role: list
  groupBy:
  - field: thread_type
    title: 按线程类型分布
  fields:
  - key: thread_name
    label: 线程名
  - key: cpu_time_ms
    label: CPU 时间
    format: '{{value}} ms'
  - key: big_core_percent
    label: 大核占比
    format: '{{value}}%'
display:
  level: key
  layer: overview
  title: 线程 CPU 使用 Top10
  columns:
  - name: tid
    label: TID
    type: number
  - name: thread_name
    label: 线程名
    type: string
  - name: cpu_time_ms
    label: CPU 时间
    type: duration
    format: duration_ms
    unit: ms
  - name: sched_count
    label: 调度次数
    type: number
    format: compact
  - name: avg_slice_ms
    label: 平均片长
    type: duration
    format: duration_ms
    unit: ms
  - name: thread_type
    label: 线程类型
    type: string
  - name: big_core_percent
    label: 大核占比
    type: percentage
    format: percentage
save_as: thread_usage
condition: target_process.data.length > 0
```
### 主线程状态分布

- ID: `main_thread_states`
- Type: `atomic`
- SQL: [`../sql/cpu_analysis/main_thread_states.sql`](../sql/cpu_analysis/main_thread_states.sql)

```yaml
id: main_thread_states
type: atomic
optional: true
synthesize:
  role: overview
  fields:
  - key: state_desc
    label: 状态
  - key: total_dur_ms
    label: 持续时间
    format: '{{value}} ms ({{percent}}%)'
  insights:
  - condition: state === 'Running' && percent < (running_threshold_pct || 50)
    template: 主线程 Running 仅 {{percent}}%，存在等待或阻塞
  - condition: state === 'R' && percent > 20
    template: 调度等待占比 {{percent}}%，CPU 资源争抢
display:
  level: key
  layer: overview
  title: 主线程状态
  columns:
  - name: state
    label: 状态码
    type: string
  - name: state_desc
    label: 状态
    type: string
  - name: total_dur_ms
    label: 持续时间
    type: duration
    format: duration_ms
    unit: ms
  - name: percent
    label: 占比
    type: percentage
    format: percentage
  - name: count
    label: 次数
    type: number
    format: compact
  - name: io_wait
    label: io_wait
    type: number
save_as: main_thread_states
condition: target_process.data.length > 0
```
### 调度延迟分析

- ID: `runnable_latency`
- Type: `atomic`
- SQL: [`../sql/cpu_analysis/runnable_latency.sql`](../sql/cpu_analysis/runnable_latency.sql)

```yaml
id: runnable_latency
type: atomic
optional: true
synthesize:
  role: list
  groupBy:
  - field: severity
    title: 按严重程度分布
  - field: waker_process
    title: 按唤醒进程分布
  fields:
  - key: wait_ms
    label: 等待时间
    format: '{{value}} ms'
  - key: waker_thread
    label: 唤醒线程
  - key: severity
    label: 严重程度
display:
  level: key
  layer: list
  title: 调度延迟分析（Runnable 等待）
  columns:
  - name: wait_ms
    label: 等待时间
    type: duration
    format: duration_ms
    unit: ms
  - name: ts_str
    label: 时间戳
    type: timestamp
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 持续时间
    type: duration
    format: duration_ms
    unit: ns
  - name: thread_name
    label: 线程名
    type: string
  - name: waker_thread
    label: 唤醒线程
    type: string
  - name: waker_process
    label: 唤醒进程
    type: string
  - name: severity
    label: 严重程度
    type: string
save_as: runnable_delays
condition: target_process.data.length > 0
```
### 主线程核心分布

- ID: `main_thread_cores`
- Type: `atomic`
- SQL: [`../sql/cpu_analysis/main_thread_cores.sql`](../sql/cpu_analysis/main_thread_cores.sql)

```yaml
id: main_thread_cores
type: atomic
display:
  level: detail
  layer: list
  title: 主线程运行核心分布
  columns:
  - name: cpu
    label: CPU
    type: number
  - name: capacity
    label: Capacity
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: total_time_ms
    label: 运行时间
    type: duration
    format: duration_ms
    unit: ms
  - name: percent
    label: 占比
    type: percentage
    format: percentage
  - name: slice_count
    label: 调度次数
    type: number
    format: compact
save_as: main_thread_cores
condition: target_process.data.length > 0
```
### 阻塞函数分析

- ID: `blocked_functions`
- Type: `atomic`
- SQL: [`../sql/cpu_analysis/blocked_functions.sql`](../sql/cpu_analysis/blocked_functions.sql)

```yaml
id: blocked_functions
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 主线程阻塞函数
  columns:
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: state
    label: 状态
    type: string
  - name: count
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
  - name: io_wait
    label: io_wait
    type: number
  - name: evidence_strength
    label: 证据强度
    type: string
save_as: blocked_functions
condition: target_process.data.length > 0
```
### CPU 频率分布

- ID: `cpu_frequency_distribution`
- Type: `atomic`
- SQL: [`../sql/cpu_analysis/cpu_frequency_distribution.sql`](../sql/cpu_analysis/cpu_frequency_distribution.sql)

```yaml
id: cpu_frequency_distribution
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: CPU 频率使用分布
  columns:
  - name: cpu
    label: CPU
    type: number
  - name: capacity
    label: Capacity
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: freq_mhz
    label: 频率 (MHz)
    type: number
    format: compact
  - name: duration_ms
    label: 持续时间
    type: duration
    format: duration_ms
    unit: ms
  - name: percent
    label: 占比
    type: percentage
    format: percentage
save_as: cpu_freq
condition: target_process.data.length > 0
```
### 唤醒链分析

- ID: `wakeup_chain`
- Type: `atomic`
- SQL: [`../sql/cpu_analysis/wakeup_chain.sql`](../sql/cpu_analysis/wakeup_chain.sql)

```yaml
id: wakeup_chain
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 主线程唤醒者分析
  columns:
  - name: waker_thread
    label: 唤醒线程
    type: string
  - name: waker_process
    label: 唤醒进程
    type: string
  - name: wakeup_count
    label: 唤醒次数
    type: number
    format: compact
  - name: total_wait_before_wakeup_ms
    label: 总等待时间
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_wait_ms
    label: 平均等待
    type: duration
    format: duration_ms
    unit: ms
  - name: irq_wakeups
    label: IRQ 唤醒
    type: number
save_as: wakeup_chain
condition: target_process.data.length > 0
```
### 线程亲和性探针

- ID: `thread_affinity_probe`
- Type: `skill`

```yaml
id: thread_affinity_probe
type: skill
skill: thread_affinity_violation
params:
  package: ${target_process.data[0]?.process_name || package || ''}
  start_ts: ${start_ts ?? null}
  end_ts: ${end_ts ?? null}
  migration_ratio_threshold: ${affinity_probe_migration_ratio_threshold_pct|25}
display:
  level: detail
  layer: list
  title: 线程迁核稳定性（专家探针）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: run_samples
    label: 运行样本
    type: number
  - name: distinct_cpus
    label: 涉及 CPU 数
    type: number
  - name: migration_count
    label: 迁核次数
    type: number
  - name: migration_ratio_pct
    label: 迁核占比
    type: percentage
    format: percentage
  - name: affinity_violation
    label: 亲和性异常
    type: boolean
save_as: affinity_probe
condition: enable_expert_probes !== false && target_process.data.length > 0
optional: true
```
### Cache Miss 计数器检测

- ID: `cache_counter_check`
- Type: `atomic`
- SQL: [`../sql/cpu_analysis/cache_counter_check.sql`](../sql/cpu_analysis/cache_counter_check.sql)

```yaml
id: cache_counter_check
type: atomic
display: false
save_as: cache_counter_check
condition: enable_expert_probes !== false && target_process.data.length > 0
optional: true
```
### Cache Miss 探针

- ID: `cache_miss_probe`
- Type: `skill`

```yaml
id: cache_miss_probe
type: skill
skill: cache_miss_impact
params:
  start_ts: ${start_ts ?? null}
  end_ts: ${end_ts ?? null}
  high_impact_threshold: ${cache_miss_high_avg_delta_threshold|500000}
  medium_impact_threshold: ${cache_miss_medium_avg_delta_threshold|100000}
display:
  level: detail
  layer: list
  title: Cache Miss 影响（专家探针）
  columns:
  - name: counter_name
    label: 计数器
    type: string
  - name: samples
    label: 样本数
    type: number
  - name: total_miss_delta
    label: 累计增量
    type: number
    format: compact
  - name: avg_miss_delta
    label: 平均增量
    type: number
    format: compact
  - name: peak_miss_delta
    label: 峰值增量
    type: number
    format: compact
  - name: impact_level
    label: 影响等级
    type: string
save_as: cache_miss_probe
condition: enable_expert_probes !== false && target_process.data.length > 0 && cache_counter_check.data[0]?.has_cache_counter
  === 1
optional: true
```
### CPU 诊断

- ID: `cpu_diagnosis`
- Type: `diagnostic`

```yaml
id: cpu_diagnosis
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
  - template: CPU 诊断：{{diagnosis}}
display:
  level: key
  layer: overview
  title: 问题诊断
inputs:
- core_stats
- main_thread_states
- runnable_delays
- blocked_functions
- affinity_probe
- cache_miss_probe
rules:
- condition: '(core_stats?.data?.length || 0) === 0 &&

    (main_thread_states?.data?.length || 0) === 0 &&

    (runnable_delays?.data?.length || 0) === 0 &&

    (blocked_functions?.data?.length || 0) === 0

    '
  severity: warning
  diagnosis: unable_to_determine：CPU 诊断数据不足（缺少 sched/thread_state 关键样本）
  confidence: low
  suggestions:
  - '[Owner] Perf/Infra | [Priority] P0 | [Action] 采集包含 sched 与 thread_state 的完整 trace（覆盖目标场景）'
  - '[Verify] 重新执行 cpu_analysis，确认 core_stats/main_thread_states/runnable_delays 均有数据'
  evidence_fields:
  - core_stats.data
  - main_thread_states.data
  - runnable_delays.data
  - blocked_functions.data
- condition: '(core_stats?.data?.length || 0) > 0 &&

    ((core_stats.data.find(c => (c.core_type || '''').includes(''big'') || (c.core_type || '''').includes(''prime''))?.percent)
    || 0) < (big_core_threshold_pct || 30)

    '
  severity: warning
  diagnosis: 大核使用率偏低 (<${big_core_threshold_pct || 30}%)
  confidence: medium
  suggestions:
  - '[Owner] Runtime/App | [Priority] P1 | [Action] 检查关键线程优先级与调度组'
  - '[Owner] System | [Priority] P1 | [Action] 评估 PowerHint/调频策略对关键线程的影响'
  - '[Verify] 对比优化前后 big/prime 核占比与帧稳定性'
  evidence_fields:
  - core_stats.data
- condition: '(main_thread_states?.data?.length || 0) > 0 &&

    ((main_thread_states.data.find(s => s.state === ''Running'')?.percent) || 0) < (running_threshold_pct || 50)

    '
  severity: warning
  diagnosis: 主线程 CPU 利用率偏低 (Running ${main_thread_states?.data?.find(s => s.state === 'Running')?.percent}%)
  confidence: medium
  suggestions:
  - '[Owner] App | [Priority] P1 | [Action] 排查主线程等待/阻塞来源（锁、IO、Binder）'
  - '[Verify] 复测 Running 比例与可交互场景帧时长'
  evidence_fields:
  - main_thread_states.data
- condition: ((runnable_delays?.data?.[0]?.wait_ms) || 0) > (sched_delay_critical_ms || 16)
  severity: critical
  diagnosis: 存在严重调度延迟 (${runnable_delays?.data?.[0]?.wait_ms}ms)
  confidence: high
  suggestions:
  - '[Owner] Perf/System | [Priority] P0 | [Action] 检查高负载与抢占来源，控制后台并发'
  - '[Owner] App | [Priority] P1 | [Action] 合并短任务，减少调度抖动'
  - '[Verify] 复测 runnable wait P95 与关键路径帧时间'
  evidence_fields:
  - runnable_delays.data
- condition: (runnable_delays?.data?.length || 0) > 10
  severity: warning
  diagnosis: 调度延迟频繁发生 (${runnable_delays?.data?.length} 次 >1ms)
  confidence: medium
  suggestions:
  - '[Owner] App | [Priority] P1 | [Action] 优化线程模型，减少线程切换'
  - '[Verify] 对比调优前后 delay 次数与上下文切换指标'
  evidence_fields:
  - runnable_delays.data
- condition: ((blocked_functions?.data?.[0]?.total_dur_ms) || 0) > (blocked_function_threshold_ms || 50)
  severity: warning
  diagnosis: 主线程 kernel blocked_function/wchan 候选为 ${blocked_functions?.data?.[0]?.blocked_function}，累计 ${blocked_functions?.data?.[0]?.total_dur_ms}ms；它是单帧阻塞点，需结合
    app slice、文件/DB、Binder 或锁链证据后再定业务根因
  confidence: medium
  suggestions:
  - '[Owner] Perf | [Priority] P1 | [Action] 交叉检查对应时间窗的 app slice、文件/DB、Binder 或 lock contention 证据'
  - '[Verify] 复测 blocked_function/io_wait 总耗时和主线程可运行占比'
  evidence_fields:
  - blocked_functions.data
- condition: ((affinity_probe?.data?.[0]?.migration_ratio_pct) || 0) >= (affinity_violation_warning_threshold_pct || 35)
  severity: warning
  diagnosis: 线程 ${affinity_probe?.data?.[0]?.thread_name} 迁核占比 ${affinity_probe?.data?.[0]?.migration_ratio_pct}% ，存在亲和性抖动
  confidence: medium
  suggestions:
  - '[Owner] Runtime/System | [Priority] P1 | [Action] 调整关键线程亲和性与调度优先级'
  - '[Verify] 复测 migration_ratio_pct 与帧稳定性'
  evidence_fields:
  - affinity_probe.data
- condition: (cache_miss_probe?.data?.find(r => r.impact_level === 'high')?.avg_miss_delta || 0) > 0
  severity: warning
  diagnosis: 检测到高缓存未命中压力 (${cache_miss_probe.data.find(r => r.impact_level === 'high').counter_name})
  confidence: medium
  suggestions:
  - '[Owner] App | [Priority] P1 | [Action] 优化数据局部性并减少 cache thrashing'
  - '[Verify] 复测 avg_miss_delta 与关键路径耗时'
  evidence_fields:
  - cache_miss_probe.data
```
## Output and evidence contract

```yaml
format: structured
```
