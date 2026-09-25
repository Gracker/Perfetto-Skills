GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/thread_system_summary_in_range.skill.yaml
Source SHA-256: 31a123f185507ef4507eccba97c35989dc3ab7c66b25bc6a4547216964c5cd8a
Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5
# 任务状态、摆核与调度观测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: thread_system_summary_in_range
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: 任务状态、摆核与调度观测
description: 范围内可定位的系统观测，保留覆盖与缺失；不单凭相关性判断根因
icon: analytics
tags:
- system
- scheduling
- evidence
- range
```

## Prerequisites

```yaml
modules:
- linux.cpu.frequency
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
- name: end_ts
  type: timestamp
  required: true
- name: package
  type: string
  required: false
- name: utid
  type: number
  required: false
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
```

## Query

Run [`../sql/thread_system_summary_in_range/query.sql`](../sql/thread_system_summary_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 任务状态、摆核与调度观测
columns:
- name: window_id
  label: window_id
  type: number
  hidden: true
- name: window_start_ts
  label: window_start_ts
  type: timestamp
  unit: ns
  hidden: true
- name: window_end_ts
  label: window_end_ts
  type: timestamp
  unit: ns
  hidden: true
- name: window_dur_ns
  label: window_dur_ns
  type: duration
  unit: ns
  hidden: true
- name: upid
  label: upid
  type: number
- name: pid
  label: pid
  type: number
- name: process_name
  label: process_name
  type: string
- name: utid
  label: utid
  type: number
- name: tid
  label: tid
  type: number
- name: thread_name
  label: thread_name
  type: string
- name: role
  label: role
  type: string
- name: total_target_threads
  label: total_target_threads
  type: number
- name: state_count
  label: state_count
  type: number
- name: state_covered_ns
  label: state_covered_ns
  type: duration
  unit: ns
- name: running_ns
  label: running_ns
  type: duration
  unit: ns
- name: runnable_ns
  label: runnable_ns
  type: duration
  unit: ns
- name: runnable_preempted_ns
  label: runnable_preempted_ns
  type: duration
  unit: ns
- name: sleeping_ns
  label: sleeping_ns
  type: duration
  unit: ns
- name: uninterruptible_ns
  label: uninterruptible_ns
  type: duration
  unit: ns
- name: other_state_ns
  label: other_state_ns
  type: duration
  unit: ns
- name: unfinished_state_ns
  label: unfinished_state_ns
  type: duration
  unit: ns
- name: state_evidence
  label: state_evidence
  type: string
- name: sched_covered_ns
  label: sched_covered_ns
  type: duration
  unit: ns
- name: big_running_ns
  label: big_running_ns
  type: duration
  unit: ns
- name: little_running_ns
  label: little_running_ns
  type: duration
  unit: ns
- name: unknown_running_ns
  label: unknown_running_ns
  type: duration
  unit: ns
- name: homogeneous_running_ns
  label: homogeneous_running_ns
  type: duration
  unit: ns
- name: topology_missing_running_ns
  label: topology_missing_running_ns
  type: duration
  unit: ns
- name: placement_mode
  label: placement_mode
  type: string
- name: topology_source
  label: topology_source
  type: string
- name: placement_evidence
  label: placement_evidence
  type: string
- name: avg_freq_khz
  label: avg_freq_khz
  type: number
- name: frequency_covered_ns
  label: frequency_covered_ns
  type: duration
  unit: ns
- name: frequency_evidence
  label: frequency_evidence
  type: string
- name: priority_min
  label: priority_min
  type: number
- name: priority_max
  label: priority_max
  type: number
- name: priority_value_count
  label: priority_value_count
  type: number
- name: priority_evidence
  label: priority_evidence
  type: string
- name: scheduling_policy_evidence
  label: scheduling_policy_evidence
  type: string
- name: affinity_evidence
  label: affinity_evidence
  type: string
- name: cgroup_evidence
  label: cgroup_evidence
  type: string
- name: uclamp_evidence
  label: uclamp_evidence
  type: string
- name: preemption_count
  label: preemption_count
  type: number
- name: preemption_evidence
  label: preemption_evidence
  type: string
- name: migrations
  label: migrations
  type: number
- name: evidence_scope
  label: evidence_scope
  type: string
```
