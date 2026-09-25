GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/thread_cpu_placement_timeline.skill.yaml
Source SHA-256: 34281aa6d8fb63c02afd70d429360ea02b61774c67d9a554d7a96c0ec77facfc
Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5
# 任务驻核时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: thread_cpu_placement_timeline
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: 任务驻核时间线
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

Run [`../sql/thread_cpu_placement_timeline/query.sql`](../sql/thread_cpu_placement_timeline/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 任务驻核时间线
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
- name: sched_id
  label: sched_id
  type: number
  hidden: true
- name: raw_start_ts
  label: raw_start_ts
  type: timestamp
  unit: ns
  hidden: true
- name: raw_dur
  label: raw_dur
  type: duration
  unit: ns
  hidden: true
- name: raw_end_ts
  label: raw_end_ts
  type: timestamp
  unit: ns
  hidden: true
- name: clipped_start_ts
  label: clipped_start_ts
  type: timestamp
  unit: ns
- name: clipped_end_ts
  label: clipped_end_ts
  type: timestamp
  unit: ns
- name: dur_ns
  label: dur_ns
  type: duration
  unit: ns
- name: is_unfinished
  label: is_unfinished
  type: number
- name: left_censored
  label: left_censored
  type: number
- name: right_censored
  label: right_censored
  type: number
- name: ucpu
  label: ucpu
  type: number
- name: cpu
  label: cpu
  type: number
- name: machine_id
  label: machine_id
  type: number
  hidden: true
- name: cluster_id
  label: cluster_id
  type: number
  hidden: true
- name: capacity
  label: capacity
  type: number
- name: core_type
  label: core_type
  type: string
- name: topology_source
  label: topology_source
  type: string
- name: priority
  label: priority
  type: number
- name: end_state
  label: end_state
  type: string
- name: scheduling_policy_evidence
  label: scheduling_policy_evidence
  type: string
- name: placement_mode
  label: placement_mode
  type: string
- name: placement_evidence
  label: placement_evidence
  type: string
- name: evidence_scope
  label: evidence_scope
  type: string
```
