GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/kernel/scheduler_module.skill.yaml
Source SHA-256: 67ddcf3a040cfc8fb5ace854ca824d699330c03bfd3894272d6df7d804f91677
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
  diagnosis: 观测大核窗口均频 ${freq_data.data.find(f => f.core_type === 'big')?.avg_freq_mhz}MHz；需结合覆盖、容量和直接限频/策略证据解释
  confidence: medium
  suggestions:
  - 是否限频以同窗口的 CPU 限频证据（cpu_throttling_in_range）为准
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
