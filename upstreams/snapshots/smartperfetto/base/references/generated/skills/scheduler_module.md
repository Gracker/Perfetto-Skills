GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/kernel/scheduler_module.skill.yaml
Source SHA-256: 8a8766ab483cb11df87f4263431bba840d057a3ef4a846e42cbf605a76e2062c
Source commit: e7ff73a937cc66d89fdc69d59728025734759acd
# 内核调度分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: scheduler_module
version: '1.0'
type: composite
category: kernel
```

## Metadata

```yaml
display_name: 内核调度分析
description: 分析线程调度延迟、CPU 利用率和大小核分配
tags:
- kernel
- scheduler
- cpu
- runnable
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
  description: Target package name
- name: tid
  type: number
  required: false
  description: Target thread ID
- name: start_ts
  type: timestamp
  required: false
  description: Analysis start timestamp
- name: end_ts
  type: timestamp
  required: false
  description: Analysis end timestamp
```

## Module contract

```yaml
layer: kernel
component: Scheduler
subsystems:
- runqueue
- cfs
- core_affinity
relatedModules:
- hardware_cpu
- framework_ams
```

## Dialogue guidance

```yaml
capabilities:
- id: thread_scheduling_delay
  questionTemplate: Why was thread {tid} delayed between {start_ts} and {end_ts}?
  requiredParams:
  - tid
  - start_ts
  - end_ts
  description: Analyze why a specific thread had scheduling delays
- id: cpu_utilization
  questionTemplate: What is the CPU utilization for package {package}?
  requiredParams:
  - package
  optionalParams:
  - start_ts
  - end_ts
  description: Analyze CPU usage patterns
- id: runnable_analysis
  questionTemplate: What threads are in runnable state competing with {tid}?
  requiredParams:
  - tid
  description: Analyze runnable queue contention
findingsSchema:
- id: high_runnable_time
  severity: warning
  titleTemplate: 'Thread scheduling delay: {delay_ms}ms in runnable state'
  descriptionTemplate: Thread {tid} waited {delay_ms}ms in runnable state with cause requiring direct contention evidence
  evidenceFields:
  - tid
  - delay_ms
  - core_type
  - waker_thread
- id: cpu_throttling
  severity: critical
  titleTemplate: 'Observed CPU frequency: avg {avg_freq_mhz}MHz'
  descriptionTemplate: Time-weighted CPU frequency is {avg_freq_mhz}MHz; thermal or policy limitation requires direct evidence
  evidenceFields:
  - avg_freq_mhz
  - max_freq_mhz
  - throttle_reason
- id: small_core_bound
  severity: warning
  titleTemplate: Observed small-core residency
  descriptionTemplate: Thread {tid} running on small cores ({small_core_pct}%)
  evidenceFields:
  - tid
  - small_core_pct
  - big_core_pct
suggestionsSchema:
- id: check_binder_waker
  condition: waker_process != package
  targetModule: binder_module
  questionTemplate: What Binder calls did {waker_process} make to {package}?
  paramsMapping:
    caller: waker_process
    callee: package
  priority: 1
- id: check_cpu_frequency
  condition: avg_freq_mhz < max_freq_mhz * 0.7
  targetModule: hardware_cpu_module
  questionTemplate: Why is CPU frequency low for core {core_id}?
  paramsMapping:
    core_id: core_id
  priority: 2
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
### Runnable 状态分析

- ID: `runnable_analysis`
- Type: `atomic`
- SQL: [`../sql/scheduler_module/runnable_analysis.sql`](../sql/scheduler_module/runnable_analysis.sql)

```yaml
id: runnable_analysis
type: atomic
process_scope:
  role: target
  binding: effective_target_processes
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/system_thread_state_spans.sql
display:
  level: detail
  layer: overview
  title: 线程 Runnable 分析
save_as: runnable_data
synthesize: true
```
### CPU 频率分析

- ID: `cpu_frequency`
- Type: `atomic`
- SQL: [`../sql/scheduler_module/cpu_frequency.sql`](../sql/scheduler_module/cpu_frequency.sql)

```yaml
id: cpu_frequency
type: atomic
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
- fragments/system_cpu_frequency_spans.sql
display:
  level: detail
  layer: overview
  title: CPU 频率统计
save_as: freq_data
synthesize: true
```
### 大小核分布

- ID: `core_distribution`
- Type: `atomic`
- SQL: [`../sql/scheduler_module/core_distribution.sql`](../sql/scheduler_module/core_distribution.sql)

```yaml
id: core_distribution
type: atomic
process_scope:
  role: target
  binding: effective_target_processes
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/system_sched_spans.sql
display:
  level: detail
  layer: list
  title: 关键线程大小核分布
save_as: core_data
synthesize: true
```
### 调度诊断

- ID: `scheduling_diagnosis`
- Type: `diagnostic`

```yaml
id: scheduling_diagnosis
type: diagnostic
inputs:
- runnable_data
- freq_data
- core_data
rules:
- condition: runnable_data.data[0]?.runnable_ms > 50
  diagnosis: 线程 ${runnable_data.data[0]?.thread_name} Runnable 等待时间过长 (${runnable_data.data[0]?.runnable_ms}ms)；需结合交接任务与唤醒证据确定原因
  confidence: high
  suggestions:
  - 检查是否有后台线程占用 CPU
  - 核对已采集的调度策略、优先级与对端任务
  evidence_fields:
  - runnable_data.data[0].thread_name
  - runnable_data.data[0].runnable_ms
- condition: freq_data.data.find(f => f.core_type === 'big')?.avg_freq_mhz < 1500
  diagnosis: 观测大核窗口均频 ${freq_data.data.find(f => f.core_type === 'big')?.avg_freq_mhz}MHz；需结合覆盖、容量和直接温控/策略证据解释
  confidence: medium
  suggestions:
  - 检查设备温度
  - 检查电池状态和功耗策略
  evidence_fields:
  - freq_data.data[0].avg_freq_mhz
  - freq_data.data[0].max_freq_mhz
- condition: core_data.data[0]?.small_core_pct > 50
  diagnosis: 目标线程大部分时间运行在小核 (${core_data.data[0]?.small_core_pct}%)；单凭驻留比例不能确定性能损失
  confidence: medium
  suggestions:
  - 检查 CPU 亲和性设置
  - 若采集缺少 affinity/cgroup/uclamp，明确证据缺口，不据此修改调度策略
  evidence_fields:
  - core_data.data[0].thread_name
  - core_data.data[0].small_core_pct
display:
  level: key
  layer: overview
  title: 调度诊断结果
```
